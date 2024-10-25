# common functions for public scripts, must be prefixed/pseudo namespaced with 
# fc_<xxxx>  for function-common, to not clash with other implementations

fc_get_full_path_script_executed_in() {
    script_path="${BASH_SOURCE[0]}"
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    echo "$script_dir"
}



# function to check if a command is in path
fc_test_command_in_path() {
        if command -v $1 >/dev/null 2>&1; then
                return 0
        else
                return 1
        fi
}

# Get numeric log level based on string value
fc_get_log_level_num() {
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
fc_should_log() {
    local message_level="$1"
    local current_level="${BASH_LOGLEVEL:-INFO}"  # Default to INFO if BASH_LOGLEVEL is not set

    local message_level_num
    local current_level_num
    message_level_num=$(get_log_level_num "$message_level")
    current_level_num=$(get_log_level_num "$current_level")

    [ "$message_level_num" -ge "$current_level_num" ]
}

# Logging functions
fc_log_debug() {
    should_log "DEBUG" && echo -e "\033[0;36m[DEBUG]\033[0m $1"  # Cyan
}

fc_log_info() {
    should_log "INFO" && echo -e "\033[0;32m[INFO]\033[0m $1"   # Green
}

fc_log_warn() {
    should_log "WARN" && echo -e "\033[0;33m[WARN]\033[0m $1"   # Yellow
}

fc_log_error() {
    should_log "ERROR" && echo -e "\033[0;31m[ERROR]\033[0m $1"  # Red
}

fc_log_fatal() {
    should_log "FATAL" && echo -e "\033[1;31m[FATAL]\033[0m $1"  # Bold Red
}

# Create a temporary file and return its name
fc_get_temp_filename() {
    mktemp /tmp/script_processing.XXXXXX
}

# Write lines to a specified file
fc_write_to_file() {
    local temp_file="$1"
    shift
    printf "%s\n" "$@" >> "$temp_file"
}

# Get the parent directory of the script
fc_get_parent_directory() {
    local script_dir
    script_dir=$(dirname "$(realpath "$0")")
    dirname "$script_dir"
}
# Function to test if an environment variable is defined
fc_test_env_variable_defined() {
    local var_name="$1"
    if [ -z "${!var_name+x}" ]; then
        return 1  # variable is not defined or empty string
    else
        return 0  # variable is set
    fi
}
