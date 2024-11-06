#!/bin/bash

## UTIL _create_repo_bundle: Clone repositories listed in a YAML file
_create_repo_bundle() {
    : '
        Clone repositories from a YAML file.

        ShortDesc: Clones all Git repositories specified in the provided YAML file into a temporary directory.

        Description:
        This function uses `yq` to parse a YAML file and extracts the repository URLs from a list
        defined under the `.repos[]` key. Each repository is cloned into the specified temporary
        directory. If `yq` is not installed, the function exits with an error message.

        Parameters:
        - $1: Path to the YAML file containing repository URLs.
        - $2: Path to the temporary directory where repositories will be cloned.

        Example usage:
        _create_repo_bundle "repos.yaml" "/tmp/repos"

        Example YAML file:
        ```yaml
        repos:
          - https://github.com/example/repo1.git
          - https://github.com/example/repo2.git
          - https://github.com/example/repo3.git

        additional_dirs:
          - /this/is/a/full/path/to/xxxdir
          - /another/full/path/to/yyydir
        ```
    '
    local yaml_file="$1"
    local temp_dir="$2"

    if ! command -v yq &> /dev/null; then
        echo "yq command could not be found. Please install yq to parse YAML files."
        exit 1
    fi

    # Clone repositories
    local repos
    repos=$(yq -r '.repos[]' "$yaml_file")
    for repo in $repos; do
        git clone "$repo" "$temp_dir/$(basename "$repo" .git)"
    done

    # Copy additional directories, retaining only the last directory name
    local dirs
    dirs=$(yq -r '.additional_dirs[]' "$yaml_file")
    for dir in $dirs; do
        cp -r "$dir" "$temp_dir/$(basename "$dir")"
    done
}

## UTIL _copy_scripts: Copy the scripts directory to the temporary directory
_copy_scripts() {
    : '
        Copy scripts to a temporary directory.

        ShortDesc: Copies the specified scripts directory to a temporary location.

        Description:
        This function copies the entire scripts directory from the provided path to
        a specified temporary directory, retaining only the last part of the directory name.
        If the scripts directory is not specified, it defaults to `./scripts`.

        Parameters:
        - $1: Path to the temporary directory where the scripts will be copied.
        - $2: Path to the scripts directory. Defaults to `./scripts` if not provided.

        Example usage:
        _copy_scripts "/tmp/repos" "./custom_scripts"
    '
    local temp_dir="$1"
    local scripts_dir="${2:-./scripts}"
    cp -r "$scripts_dir" "$temp_dir/$(basename "$scripts_dir")"
}

## UTIL _create_self_extracting_binary: Create a self-extracting binary
_create_self_extracting_binary() {
    : '
        Create a self-extracting binary from the cloned repositories and scripts.

        ShortDesc: Packages cloned repositories and scripts into a self-extracting binary.

        Description:
        This function creates a tarball of the provided temporary directory and embeds it into
        a self-extracting Bash binary. The binary extracts the contents to a temporary directory
        and runs a `run.sh` script from the extracted files.

        Parameters:
        - $1: Name of the output self-extracting binary.
        - $2: Path to the temporary directory containing the files to be packaged.

        Example usage:
        _create_self_extracting_binary "installer.bin" "/tmp/repos"
    '
    local output_binary="$1"
    local temp_dir="$2"

    local tarball="$temp_dir/bundle.tar.gz"
    tar -czf "$tarball" -C "$temp_dir" .

    mkdir -p "./build"

    {
        echo '#!/bin/bash'
        echo 'TEMP_DIR=$(mktemp -d)'
        echo 'ARCHIVE=$(mktemp)'
        echo 'tail -n +12 "$0" > "$ARCHIVE"'
        echo 'tar -xzf "$ARCHIVE" -C "$TEMP_DIR"'
        echo 'rm -f "$ARCHIVE"'
        echo 'echo "All files have been extracted to $TEMP_DIR"'
        echo 'echo "Now executing run.sh"'
        echo 'cd $TEMP_DIR/scripts/ && ./run.sh'
        echo 'exit 0'
        echo ''
        cat "$tarball"
    } > "./build/$output_binary"

    chmod +x "./build/$output_binary"
    rm -rf "$temp_dir"

    echo "Self-extracting binary created: ./build/$output_binary"
}

## UTIL build_installer: Main function to create the installer
build_installer() {
    : '
        Build a self-extracting installer binary.

        ShortDesc: Packages repositories, additional directories, and scripts into a self-extracting installer binary.

        Description:
        This function orchestrates the creation of a self-extracting installer. It creates a
        temporary directory, clones repositories, copies scripts, includes additional directories,
        and packages everything into a self-extracting Bash binary.
		This is a very useful tool to build installation packages for servers which dont have internet connection.
		Like for init installation of vanilla systems

        Parameters:
        - --yaml-file: Path to the YAML file containing repository URLs and additional directories.
        - --output-binary: Name of the output self-extracting binary.
        - --scripts-dir: Path to the scripts directory. Defaults to `./scripts` if not provided.

        Example usage:
        build_installer --yaml-file "repos.yaml" --output-binary "installer.bin" --scripts-dir "./custom_scripts"

        Example YAML file:
        ```yaml
        repos:
          - https://github.com/example/repo1.git
          - https://github.com/example/repo2.git
          - https://github.com/example/repo3.git

        additional_dirs:
          - /this/is/a/full/path/to/xxxdir
          - /another/full/path/to/yyydir
        ```

        How to Work with the Generated Installer Binary:
        1. Run the generated self-extracting binary:
           ```bash
           ./build/installer.bin
           ```

        2. The binary will:
           - Extract all files to a temporary directory.
           - Change directory to `scripts` and run `run.sh`.

        Ensure `run.sh` exists in your specified `scripts` directory and is executable.
    '
    local yaml_file=""
    local output_binary=""
    local scripts_dir="./scripts"

    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --yaml-file)
                yaml_file="$2"
                shift 2
                ;;
            --output-binary)
                output_binary="$2"
                shift 2
                ;;
            --scripts-dir)
                scripts_dir="$2"
                shift 2
                ;;
            *)
                echo "Unknown parameter passed: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$yaml_file" || -z "$output_binary" ]]; then
        echo "Usage: build_installer --yaml-file <path> --output-binary <name> [--scripts-dir <path>]"
        exit 1
    fi

    local temp_dir
    temp_dir=$(mktemp -d)

    _create_repo_bundle "$yaml_file" "$temp_dir"
    _copy_scripts "$temp_dir" "$scripts_dir"
    _create_self_extracting_binary "$output_binary" "$temp_dir"

    rm -rf "$temp_dir"
}

## Entry point of the script
main() {
    build_installer "$@"
}

main "$@"
