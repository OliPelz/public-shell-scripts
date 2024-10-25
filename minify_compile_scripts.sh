#!/bin/bash

# Script to process shell files, filter comments, and write processed output
# Usage:
# --allowed_extensions: comma-separated extensions (e.g. sh,bash)
# --input_dir: directory to search (optional, defaults to parent dir)
# --dir_whitelist: comma-separated list of specific directory names to process (optional)
# --whitelist_regex: regex to match directories or files (optional)
# --output_full_base_path: full path to the output file, without extension, e.g. /tmp/a/b/c instead of  /tmp/a/b/c.sh



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
			fc_log_debug "keep preprocessor line '${line}'"
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

		find_exclude_param=""
        if test -s ${dir_name}/__EXCLUDE_FILES; then
			# build exclude list for find command
			find_exclude_params="$(printf "! -path '%s' " $(cat ${dir_name}/__EXCLUDE_FILES))"
            fc_log_debug "found exclude file beneath ${dir_name}, generated find args: ${find_exclude_params}"
        fi
		fc_log_info "processing files in folder '${dir_name}'"

        # Process allowed extensions
        for file_type in "${allowed_extension_types[@]}"; do
            while IFS= read -r -d '' file; do
                [[ "$file" == *__* || "$file" == *_PLACEHOLDER* ]] && continue
                if [[ "$file" == *."$file_type" ]]; then
                    fc_log_debug "$file"
                    cat "$file" >> "$output_file"
                fi
            done < <(find "$dirpath" -type f -print0 ${find_exclude_param})
        done
    done
}

# Function to show usage
usage() {
    echo "Usage: $0 --allowed_extensions ext1,ext2 --output_full_base_path OUTPUT_FILE_FULL_PATH [--dir_whitelist WHITELIST] [--whitelist_regex REGEX] [--input_dir INPUT_DIR]"
}


main() {
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --allowed_extensions) IFS=',' read -r -a allowed_extensions <<< "$2"; shift ;;
            --input_dir) input_dir="$2"; shift ;;
            --output_full_base_path) output_full_base_path="$2"; shift ;;
            --dir_whitelist) IFS=',' read -r -a dir_whitelist <<< "$2"; shift ;;
            --whitelist_regex) whitelist_regex="$2"; shift ;;
			--debug) debug="$2"; shift ;;
            *) fc_log_error "Unknown parameter passed: $1"; usage; exit 1 ;;
        esac
        shift
    done

	if fc_test_command_in_path preprocess; then
		fc_log_error "mandantory commandline interface 'preprocess' (python) not installed"
	fi

    # Check mandatory arguments
    if [ -z "$allowed_extensions" ] || [ -z "$output_full_base_path" ]; then
        fc_log_error "Missing required arguments."
        usage
        exit 1
    fi

    # Check if output_full_base_path starts with "__"
    if [[ "$(basename "$output_full_base_path")" == __* ]]; then
        fc_log_error "Error: Output file path cannot start with '__'."
        exit 1
    fi

    # Set input_dir to parent directory if not provided
    if ! fc_test_env_variable_defined input_dir; then
        input_dir=$(get_parent_directory)
    fi

    # Create temporary files for processing
    all_lines_file=$(get_temp_filename)

    # concat the files and save the result to a temporary file
    concat_files_content "$input_dir" allowed_extensions[@] dir_whitelist[@] "$whitelist_regex" "$all_lines_file"

	# loop over all supported shell variants
	for shell_variant in BASH ZSH; then

		processed_lines_file=$(get_temp_filename)
		prepared_lines_file=$(get_temp_filename)
		minified_lines_file=$(get_temp_filename)

	# now lets run the preprocessor step (currently this is a python module installed from pip)
		preprocess -D SHELL_IS_${shell_variant}=true -v -f {all_lines_file} -o ${processed_lines_file} 

    # Prepare and minify the lines, using temporary files
		prepare_processor "$processed_lines_file" "$prepared_lines_file"
		minify_shell_code "$prepared_lines_file" "$minified_lines_file"

    # Write the output to the final output file
		final_output_file="${output_full_base_path}.${shell_variant@L}"

		mv "$minified_lines_file" "${final_output_file}"

		if fc_test_env_variable_defined debug; then
			cp "$all_lines_file" "$output_full_base_path.debug"
			fc_log_info "debug file written to '$output_full_base_path.debug'"
			fc_log_info "e.g. do vimdiff '$output_full_base_path.debug' '$output_full_base_path'"
		fi
		# Clean up temporary files
		rm "$all_lines_file" "$processed_lines_file" "$prepared_lines_file"

		fc_log_info "final processed and minified file written to '${final_output_file}'"
}

main "$@"

