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

