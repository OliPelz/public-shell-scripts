#!/bin/bash

function download_from_private_github {
    : '
    Download from Private GitHub Repository

    ShortDesc: Downloads a file from a private GitHub repository using a Personal Access Token (PAT).

    Description:
    This function allows you to download a specific file from a private GitHub repository. It uses a personal access token
    for authentication and the GitHub API to retrieve the file from the specified repository and branch. If the file exists
    locally, it will be overwritten. If no output filename is provided, the file will be saved with the same name as in
    the repository.

    Parameters:
    - GITHUB_TOKEN: Personal Access Token (PAT) with access to the private repository.
    - REPO_OWNER: GitHub repository owner (user or organization name).
    - REPO_NAME: Name of the GitHub repository.
    - FILE_PATH: The path to the file in the repository to download.
    - BRANCH: The branch to download the file from (optional, defaults to "main").
    - OUTPUT_FILE: Local file name to save the downloaded content (optional).

    Returns:
    - 0: Success (file downloaded successfully)
    - 1: Failure (missing parameters or file download failed)

    Example Usage:
    download_from_private_github "your_personal_access_token" "owner" "repo" "path/to/file.txt"
    download_from_private_github "your_personal_access_token" "owner" "repo" "path/to/file.txt" "main" "local_file.txt"

    '

    local GITHUB_TOKEN=$1
    local REPO_OWNER=$2
    local REPO_NAME=$3
    local FILE_PATH=$4
    local BRANCH=${5:-main}
    local OUTPUT_FILE=${6:-$(basename "$FILE_PATH")}

    # Validate arguments
    if [[ -z "$GITHUB_TOKEN" || -z "$REPO_OWNER" || -z "$REPO_NAME" || -z "$FILE_PATH" ]]; then
        echo "Usage: download_from_private_github <GITHUB_TOKEN> <REPO_OWNER> <REPO_NAME> <FILE_PATH> [<BRANCH>] [<OUTPUT_FILE>]"
        return 1
    fi

    # Download the file using curl
    curl -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3.raw" \
         -L "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE_PATH?ref=$BRANCH" \
         -o "$OUTPUT_FILE"

    # Check if the file was successfully downloaded
    if [[ $? -eq 0 ]]; then
        echo "File downloaded successfully to $OUTPUT_FILE."
        return 0
    else
        echo "Failed to download the file."
        return 1
    fi
}

# Example usage (uncomment to test):
# download_from_private_github "your_personal_access_token" "owner" "repo" "path/to/file.txt" "main" "output.txt"


function download_directory_from_github {
    : '
    Download a directory from a private GitHub repository using the GitHub API

    ShortDesc: Downloads all files in a specific directory from a private GitHub repository.

    Parameters:
    - GITHUB_TOKEN: Personal Access Token (PAT) with access to the private repository.
    - REPO_OWNER: GitHub repository owner (user or organization name).
    - REPO_NAME: Name of the GitHub repository.
    - DIRECTORY_PATH: The path of the directory to download.
    - BRANCH: The branch to download the directory from (optional, defaults to "main").
    - TARGET_DIR: Local directory where the files will be downloaded.

    Returns:
    - 0: Success (directory downloaded successfully)
    - 1: Failure (missing parameters or directory download failed)

    Example Usage:
    download_directory_from_github "your_personal_access_token" "owner" "repo" "path/to/directory" "main" "local_dir"
    '

    local GITHUB_TOKEN=$1
    local REPO_OWNER=$2
    local REPO_NAME=$3
    local DIRECTORY_PATH=$4
    local BRANCH=${5:-main}
    local TARGET_DIR=${6:-$(basename "$DIRECTORY_PATH")}

    if [[ -z "$GITHUB_TOKEN" || -z "$REPO_OWNER" || -z "$REPO_NAME" || -z "$DIRECTORY_PATH" ]]; then
        echo "Usage: download_directory_from_github <GITHUB_TOKEN> <REPO_OWNER> <REPO_NAME> <DIRECTORY_PATH> [<BRANCH>] [<TARGET_DIR>]"
        return 1
    fi

    # Create target directory if it does not exist
    mkdir -p "$TARGET_DIR"

    # Fetch the file list from GitHub API
    file_list=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                     -H "Accept: application/vnd.github.v3+json" \
                     "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$DIRECTORY_PATH?ref=$BRANCH")

    # Download each file
    echo "$file_list" | jq -r '.[] | select(.type == "file") | .download_url' | while read -r file_url; do
        file_name=$(basename "$file_url")
        curl -H "Authorization: token $GITHUB_TOKEN" -L "$file_url" -o "$TARGET_DIR/$file_name"
    done

    echo "Directory downloaded successfully to $TARGET_DIR."
    return 0
}

