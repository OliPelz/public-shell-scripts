#!/usr/bin/env bash

# small function collection

is_root() {
   if [[ $EUID -ne 0 ]]; then
      return 1
   fi
   return 0

test_env_variable_defined() {
        ARG=$1
        CMD='test -z ${'$ARG'+x}'
        if eval $CMD;
        then
                return 1 # variable is not defined or empty string
        else
                return 0  # variable is set
        fi
}

function is_var_true() {
    local var_name="$1"  # Store the variable name
    local var_value

    # Call test_env_variable_defined with the variable name as a string
    if test_env_variable_defined "${var_name}"; then
        # Access the value of the variable using indirect expansion
        var_value="${!var_name,,}"  # Convert the value to lowercase

        if [ "${var_value}" == "true" ]; then
            return 0  # Success, the variable is set and true
        fi
    fi

    return 1  # Failure, the variable is either not set or not true
}


create_temp() {
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

detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID}" in
            fedora|centos|rhel)
                return "RHEL"
                ;;
            arch)
                return "ARCH"
                ;;
            ubuntu|debian)
                return "DEBIAN"
                ;;
            *)
                echo "Unsupported distribution: ${ID}"
                return "NONE"
                ;;
        esac
    else
        echo "Cannot determine distribution."
        return "NONE"
    fi
}
