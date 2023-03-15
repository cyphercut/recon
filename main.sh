#!/usr/bin/env bash

# Load variables from .env file
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found. Please create a .env file in the script directory with required variables."
    exit 1
fi

# Function to check and install required tools
check_required_tools() {
    TOOLS_JSON=$(cat tools.json)
    TOOLS_LIST=$(echo "$TOOLS_JSON" | jq -r '.tools[].name')

    for tool in $TOOLS_LIST; do
        tool_install_cmd=$(echo "$TOOLS_JSON" | jq -rc --arg tool_name "$tool" '.tools[] | select(.name == $tool_name) | .install')
        tool_commands=$(echo "$TOOLS_JSON" | jq -rc --arg tool_name "$tool" '.tools[] | select(.name == $tool_name) | .commands[]?')

        if ! command -v "$tool" > /dev/null 2>&1; then
            echo "Error: $tool is not installed or not in PATH."
            echo "Installing $tool..."
            
            
            if [[ "$tool_install_cmd" == "{"* ]]; then
                if [ "$(uname)" == "Darwin" ]; then
                    tool_install_cmd_macos=$(echo "$tool_install_cmd" | jq -r ".macos // empty")
                    if [ -n "$tool_install_cmd_macos" ]; then
                        tool_install_cmd="$tool_install_cmd_macos"
                    fi
                elif [ "$(uname)" == "Linux" ]; then
                    tool_install_cmd_ubuntu=$(echo "$tool_install_cmd" | jq -r ".ubuntu // empty")
                    if [ -n "$tool_install_cmd_ubuntu" ]; then
                        tool_install_cmd="$tool_install_cmd_ubuntu"
                    fi
                fi
            fi

            eval "$tool_install_cmd"

            if [ -n "$tool_commands" ]; then
                while IFS= read -r command_entry; do
                    label=$(echo "$command_entry" | jq -r 'to_entries[].key')
                    cmd=$(echo "$command_entry" | jq -r 'to_entries[].value')

                    echo "$label"
                    if [[ "$cmd" == "mv"* ]]; then
                        cmd_array=($cmd)
                        sudo "${cmd_array[@]}"
                    else
                        eval "$cmd"
                    fi
                done <<< "$tool_commands"
            fi
        fi
    done
}

function validate_domain() {
    if [ -z "$1" ]; then
        echo -e "\nPlease insert the target."
        echo "$ sh main.sh domain.com"
        exit 1
    fi
}

function create_directory() {
    if [ ! -d "$1" ]; then
        if ! mkdir -p "$1"; then
            echo "Error: Failed to create directory $1"
            exit 1
        fi
    fi
}

function find_subdomains() {
    subfinder -d "$1" -v | httpx | anew "$2/subdomains"
}

function scan_subdomains() {
    while IFS= read -r subdomain; do
        local subdomain_folder=$(sed 's|://|_|' <<< "$subdomain")
        create_directory "$1/$subdomain_folder"
        find_directories "$subdomain" "$1/$subdomain_folder"
        find_urls "$subdomain" "$1/$subdomain_folder"
    done < "$1/subdomains"
}

function find_directories() {
    dirsearch -u "$1" -w "$MAIN_COMMON_WORDLIST" -o "$3/dirsearch" --format=simple -x 403,301,302,508 -R 3
}

function find_urls() {
    gau "$1" --blacklist css,png,jpeg,jpg,svg,gif,ttf,woff,woff2,eot,otf,ico | httpx | anew "$2/urls"
}

# Main script execution
check_required_tools
validate_domain "$1"

domain="$1"

create_directory "$REPORTS_FOLDER/$domain"

if [ ! -f "$REPORTS_FOLDER/$domain/subdomains" ]; then
    find_subdomains "$domain" "$REPORTS_FOLDER/$domain"
fi

scan_subdomains "$REPORTS_FOLDER/$domain"