#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"

source "$LIB_SCRIPT_DIR/basic-operations.lib"

echo -e "\n📦 Installing linode-cli."
if ! command_exists linode-cli; then
    VENV_DIR="$HOME/.local/pipx/venvs/linode-cli/"
    CONF_DIR="$HOME/.config/linode"
    TOKEN_FILE="$CONF_DIR/token"

    pipx install linode-cli
    "$VENV_DIR/bin/python3" -m pip install boto3
    read -p "Please provide you're Linode Access Token: " TOKEN
    mkdir -p "$CONF_DIR"
    echo "TOKEN=$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
else
    echo -e "\t✨ Linode-CLI is already installed!"
fi

if command_exists linode-cli && file_exists "$TOKEN_FILE"; then
    print_success "Linode-CLI successfully installed"
    
else
    print_error "An problem occurred while installing Linode-CLI"
    exit 1
fi
