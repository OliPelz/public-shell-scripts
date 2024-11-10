# aboslute minimal common functions set to use!
# must be prefixed/pseudo namespaced with 
# fc_<xxxx>  for function-common, to not clash with the original
# functions names i stole them from
#
# 
# to source this file into any script do:
# s=${BASH_SOURCE:-${(%):-%x}} d=$(cd "$(dirname "$s")" && pwd) && source $d/common.sh
# 
# i copy/put this 'function set' to any new project whenever i need an essential function set
# and dont have internet as a prestep to setup and download advanced function libs 
#
# to fetch the latest copy of this script to your project do:
# curl -O __minimal_common.sh https://raw.githubusercontent.com/OliPelz/public-shell-scripts/main/common.sh
#
# then to use it in your target script use
#
# import common.sh
# s=${BASH_SOURCE:-${(%):-%x}} d=$(cd "$(dirname "$s")" && pwd) && source $d/common.sh
#

# Function to test if an environment variable is defined
fc_test_env_variable_defined() {
    local var_name="$1"
    if [ -z "${!var_name+x}" ]; then
        return 1  # variable is not defined or empty string
    else
        return 0  # variable is set
    fi
}

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
    message_level_num=$(fc_get_log_level_num "$message_level")
    current_level_num=$(fc_get_log_level_num "$current_level")

    [ "$message_level_num" -ge "$current_level_num" ]
}

# Logging functions
fc_log_debug() {
    fc_should_log "DEBUG" && echo -e "\033[0;36m[DEBUG]\033[0m $1" >&2 # Cyan
}

fc_log_info() {
    fc_should_log "INFO" && echo -e "\033[0;32m[INFO]\033[0m $1" >&2 # Green
}

fc_log_warn() {
    fc_should_log "WARN" && echo -e "\033[0;33m[WARN]\033[0m $1" >&2 # Yellow
}

fc_log_error() {
    fc_should_log "ERROR" && echo -e "\033[0;31m[ERROR]\033[0m $1" >&2 # Red
}

fc_log_fatal() {
    fc_should_log "FATAL" && echo -e "\033[1;31m[FATAL]\033[0m $1" >&2 # Bold Red
}

fc_create_temp() {
    local type="$1"
    local delete_on_exit="${2:-true}"
    local suffix="${3:-''}"
    local temp_path=""

    if [[ "$type" == "file" ]]; then
        temp_path=$(mktemp --suffix $suffix)
    elif [[ "$type" == "dir" ]]; then
        temp_path=$(mktemp -d --suffix $suffix)
    else
        echo "Invalid type specified. Use 'file' or 'dir'."
        return 1
    fi
    echo "$temp_path"

    if [[ "$delete_on_exit" == true ]]; then
        trap 'rm -rf "$temp_path"' EXIT
    fi
}

# Create a temporary file and return its name
fc_get_temp_filename() {
	fc_create_temp file false $1
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

# curl wrapper which can work behind proxy
# to use proxy feature define:
#
# - USE_PROXY: Set to true to enable proxy usage, false to disable it.
# - HTTPS_PROXY: The proxy URL to use.
# - CERT_BASE64_STRING: Base64-encoded SSL certificate string for verifying proxy connections (optional).
fc_pcurl_wrapper() {
    local url="$1"
    shift
    local additional_params="$@"

    local curl_cmd="curl"
    local proxy_cmd=""
    local cert_cmd=""

    if [ "${USE_PROXY,,}" == "true" ]; then
        if test_env_variable_defined CERT_BASE64_STRING; then
            # Create a temporary file for the cert
            TEMP_CERT_FILE=$(create_temp_file)
            echo "${CERT_BASE64_STRING}" | base64 -d > "${TEMP_CERT_FILE}"
            cert_cmd="--cacert ${TEMP_CERT_FILE}"
        fi
        proxy_cmd="--proxy ${HTTPS_PROXY}"
    fi

    # Execute curl with the appropriate options
    ${curl_cmd} ${proxy_cmd} ${cert_cmd} ${additional_params} "${url}"

    # Clean up temporary cert file if created
    if [ -n "${TEMP_CERT_FILE}" ]; then
        rm "${TEMP_CERT_FILE}"
    fi
}


