#!/bin/bash

# Script to process shell files, filter comments, and write processed output
# Usage:
# --allowed_extensions: comma-separated extensions (e.g. sh,bash)
# --input_dir: directory to search (optional, defaults to parent dir)
# --dir_whitelist: comma-separated list of specific directory names to process (optional)
# --whitelist_regex: regex to match directories or files (optional)
# --output_path: full path to the output file


# Get numeric log level based on string value
get_log_level_num() {
    case "$1" in
        DEBUG) echo 1 ;;
        INFO) echo 2 ;;
        WARN) echo 3 ;;
        ERROR) echo 4 ;;
        FATAL) echo 5 ;;
        *) echo 0 ;;  # Unknown log level
    esac
}

# Check if the current message level should be printed
should_log() {
    local message_level="$1"
    local current_level="${BASH_LOGLEVEL:-INFO}"  # Default to INFO if BASH_LOGLEVEL is not set

    local message_level_num
    local current_level_num
    message_level_num=$(get_log_level_num "$message_level")
    current_level_num=$(get_log_level_num "$current_level")

    [ "$message_level_num" -ge "$current_level_num" ]
}


# Logging functions
log_debug() {
    should_log "DEBUG" && echo -e "\033[0;36m[DEBUG]\033[0m $1"  # Cyan
}

log_info() {
    should_log "INFO" && echo -e "\033[0;32m[INFO]\033[0m $1"   # Green
}

log_warn() {
    should_log "WARN" && echo -e "\033[0;33m[WARN]\033[0m $1"   # Yellow
}

log_error() {
    should_log "ERROR" && echo -e "\033[0;31m[ERROR]\033[0m $1"  # Red
}

log_fatal() {
    should_log "FATAL" && echo -e "\033[1;31m[FATAL]\033[0m $1"  # Bold Red
}

# Create a temporary file and return its name
get_temp_filename() {
    mktemp /tmp/script_processing.XXXXXX
}

# Write lines to a specified file
write_to_file() {
    local temp_file="$1"
    shift
    printf "%s\n" "$@" >> "$temp_file"
}

# Get the parent directory of the script
get_parent_directory() {
    local script_dir
    script_dir=$(dirname "$(realpath "$0")")
    dirname "$script_dir"
}

# Prepare processor function
# there are some patterns like python comments containing the word if e.g.:
# e.g. :  # if this is a normal comment
# then this pattern '# if \w+' needs to be removed because the 
# python preprocessor named 'preprocess' can not handle it correctly
# because it is a internal keyword
prepare_processor() {
    local input_file="$1"
    local output_file="$2"
    : > "$output_file"  # Clear output file

    while IFS= read -r line; do
        if [[ ! "$line" =~ ^[[:space:]]*#\s*if\s+ ]]; then
            echo "$line" >> "$output_file"
        fi
    done < "$input_file"
}

# Minify shell code by filtering comments and processing lines
minify_shell_code() {
    local input_file="$1"
    local output_file="$2"
    : > "$output_file"  # Clear output file

    while IFS= read -r line; do
        
        # there are several keywords from python preprocess module
        # we need to keep here, full list of preprocessor statements
        if [[ "$line" =~ ^#[[:space:]]*#[[:space:]]*(define|undef|ifdef|ifndef|if|elif|else|endif|error|include) ]]; then
			log_debug "keep preprocessor line '${line}'"
            echo "$line" >> "$output_file"
            continue
        fi

        
        # skip shebang lines
        if [[ "$line" =~ ^#! ]]; then
            continue
        fi
        # skip standalone comments (comment lines)
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # remove inline comments ––> reduced line without comment 
		# 's/\s*#\s*[a-zA-Z0-9 ]*$//g' - remove inline comments only if after # only alphanum follows 
        # this prevents removing '#' sublines which is in between code like 'length=${#text}'
        # also 2 regexp for remove trailing and leading whitespaces
        local stripped_line
        stripped_line=$(echo "$line" | sed -E 's/\s*#\s*[a-zA-Z0-9 ]*$//g; s/^[[:space:]]*//; s/[[:space:]]+$//')
        if [[ -n "$stripped_line" ]]; then
            echo "$stripped_line" >> "$output_file"
        fi
    done < "$input_file"
}

# Process files and collect content based on allowed extensions
concat_files_content() {
    local script_base_path="$1"
    local allowed_extension_types=("${!2}")
    local whitelist=("${!3}")
    local whitelist_regex="$4"
    local output_file="$5"

    : > "$output_file"  # Clear output file

    for dirpath in "$script_base_path"/*/; do
        local dir_name=$(basename "$dirpath")

        # Check if directory is whitelisted (either exact match or matches regex)
        if [[ "$dir_name" == *"__"* ]] || \
           [[ ! -z "$whitelist" && ! " ${whitelist[@]} " =~ " ${dir_name} " ]] || \
           [[ ! -z "$whitelist_regex" && ! "$dirpath" =~ $whitelist_regex ]]; then
            continue
        fi
		log_info "processing files in folder '${dir_name}'"

        # Process allowed extensions
        for file_type in "${allowed_extension_types[@]}"; do
            while IFS= read -r -d '' file; do
                [[ "$file" == *__* || "$file" == *_PLACEHOLDER* ]] && continue
                if [[ "$file" == *."$file_type" ]]; then
                    log_debug "$file"
                    cat "$file" >> "$output_file"
                fi
            done < <(find "$dirpath" -type f -print0)
        done
    done
}

# Function to show usage
usage() {
    echo "Usage: $0 --allowed_extensions ext1,ext2 --output_path OUTPUT_FILE_FULL_PATH [--dir_whitelist WHITELIST] [--whitelist_regex REGEX] [--input_dir INPUT_DIR]"
}

# Function to test if an environment variable is defined
test_env_variable_defined() {
    local var_name="$1"
    if [ -z "${!var_name+x}" ]; then
        return 1  # variable is not defined or empty string
    else
        return 0  # variable is set
    fi
}

main() {
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --allowed_extensions) IFS=',' read -r -a allowed_extensions <<< "$2"; shift ;;
            --input_dir) input_dir="$2"; shift ;;
            --output_path) output_path="$2"; shift ;;
            --dir_whitelist) IFS=',' read -r -a dir_whitelist <<< "$2"; shift ;;
            --whitelist_regex) whitelist_regex="$2"; shift ;;
			--debug) debug="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
        esac
        shift
    done

    # Check mandatory arguments
    if [ -z "$allowed_extensions" ] || [ -z "$output_path" ]; then
        echo "Missing required arguments."
        usage
        exit 1
    fi

    # Check if output_path starts with "__"
    if [[ "$(basename "$output_path")" == __* ]]; then
        echo "Error: Output file path cannot start with '__'."
        exit 1
    fi

    # Set input_dir to parent directory if not provided
    if ! test_env_variable_defined input_dir; then
        input_dir=$(get_parent_directory)
    fi

    # Create temporary files for processing
    all_lines_file=$(get_temp_filename)
    prepared_lines_file=$(get_temp_filename)
    minified_lines_file=$(get_temp_filename)

    # concat the files and save the result to a temporary file
    concat_files_content "$input_dir" allowed_extensions[@] dir_whitelist[@] "$whitelist_regex" "$all_lines_file"

    # Prepare and minify the lines, using temporary files
    prepare_processor "$all_lines_file" "$prepared_lines_file"
    minify_shell_code "$prepared_lines_file" "$minified_lines_file"

    # Write the output to the final output file
    mv "$minified_lines_file" "$output_path"

    if test_env_variable_defined debug; then
		cp "$all_lines_file" "$output_path.debug"
    	log_info "debug file written to '$output_path.debug'"
    	log_info "e.g. do vimdiff '$output_path.debug' '$output_path'"
    fi
    # Clean up temporary files
    rm "$all_lines_file" "$prepared_lines_file"

    log_info "processed file written to '$output_path'"
}

main "$@"
