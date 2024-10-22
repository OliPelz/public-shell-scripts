#!/bin/bash

# Write an array of lines to a temporary file and return its name
list_to_temp_filename() {
    local lines=("$@")
    local temp_file
    temp_file=$(get_temp_filename)
    printf "%s\n" "${lines[@]}" > "$temp_file"
    echo "$temp_file"
}

# Write an array of lines to a specified file
list_to_file() {
    local lines=("$@")
    local filename="${lines[-1]}"
    unset 'lines[-1]'
    printf "%s\n" "${lines[@]}" > "$filename"
}

# Get the parent directory of the script
get_parent_directory() {
    local script_dir
    script_dir=$(dirname "$(realpath "$0")")
    dirname "$script_dir"
}

# Prepare processor function to remove comments with "if"
prepare_processor() {
    local lines=("$@")
    local processed_lines=()

    for line in "${lines[@]}"; do
        if [[ ! "$line" =~ ^[[:space:]]*#\s*if\s+ ]]; then
            processed_lines+=("$line")
        fi
    done

    echo "${processed_lines[@]}"
}

# Minify shell code by filtering comments and processing lines
minify_shell_code() {
    local lines=("$@")
    local processed_lines=()

    for line in "${lines[@]}"; do
        if [[ "$line" =~ ^#! ]]; then
            processed_lines+=("$line")
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*#\s*(define|endif|include|ifdef) ]]; then
            processed_lines+=("$line")
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        local stripped_line
        stripped_line=$(echo "$line" | sed 's/\s*#.*$//')
        if [[ -n "$stripped_line" ]]; then
            processed_lines+=("$stripped_line")
        fi
    done

    echo "${processed_lines[@]}"
}

# Process files and collect content based on allowed extensions
process_files() {
    local script_base_path="$1"
    shift
    local allowed_extension_types=("$@")
    local all_lines=()
    local function_lines=()

    for dirpath in "$script_base_path"/*/; do
        [[ "$dirpath" == *__* ]] && continue

        for file_type in "${allowed_extension_types[@]}"; do
            while IFS= read -r -d '' file; do
                [[ "$file" == *__* || "$file" == *_PLACEHOLDER* ]] && continue
                if [[ "$file" == *."$file_type" ]]; then
                    mapfile -t file_lines < "$file"
                    all_lines+=("${file_lines[@]}")

                    if [[ "$dirpath" == *functions* ]]; then
                        function_lines+=("${file_lines[@]}")
                    fi
                fi
            done < <(find "$dirpath" -type f -print0)
        done
    done

    echo "${all_lines[@]}"
    echo "${function_lines[@]}"
}


# Function to show usage
usage() {
    echo "Usage: $0 --allowed_extensions ext1,ext2 --output_path OUTPUT_FILE_FULL_PATH [--whitelist WHITELIST] [--input_dir PARENT_DIR]"
}

test_env_variable_defined(){
        ARG=$1
        CMD='test -z ${'$ARG'+x}'
        if eval $CMD;
        then
                return 1 # variable is not defined or empty string
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
			--whitelist) IFS=',' read -r -a whitelist <<< "$2"; shift ;;
			*) echo "Unknown parameter passed: $1"; usage ;;
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
	if ! [[ "$(basename "$output_path")" == __* ]]; then
		echo "Error: Output file path cannot start with '__'."
		exit 1
	fi

	if ! test_env_variable_defined input_dir; then
		input_dir=$(get_parent_directory)
	fi
	exit
	# Process the files
	lines=$(process_files "$input_dir" "${allowed_extensions[@]}")

	# Output the result to the specified file
	mkdir -p "$output_dir"
	echo "${lines[@]}" > "$output_path"

	echo "Processed and saved output to $output_path"
}

main "$@"

