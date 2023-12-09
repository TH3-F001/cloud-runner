#!/bin/bash

# Initialize file and directory variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
VENV_DIR="$HOME/.local/pipx/venvs/linode-cli/"
CONF_DIR="$HOME/.config/linode"
STACKSCRIPT_DIR="$CONF_DIR/stackscripts"
CONF_FILE="$CONF_DIR/cloud-runner.conf"

# Install and source n00b-bash libraries
echo -e "\n📦 Installing n00b-bash libs..."
TMP_DIR="/tmp/n00b-bash"
rm -rf $TMP_DIR 2>/dev/null
git clone https://github.com/TH3-F001/n00b-bash.git "$TMP_DIR"
mkdir -p "$LIB_SCRIPT_DIR"
cp "$TMP_DIR"/*.lib "$LIB_SCRIPT_DIR"


for LIB_FILE in "$LIB_SCRIPT_DIR"/*\.lib; do
    source "$LIB_FILE"
done


# Install Linode
echo -e "\n📦 Installing linode-cli."
if ! command_exists linode-cli; then
    pipx install linode-cli
    "$VENV_DIR/bin/python3" -m pip install boto3
else
    echo -e "\t✨ Linode-CLI is already installed!"
fi


# Ask for Linode token
if ! file_exists "$TOKEN_FILE"; then
    read -p "Please provide you're Linode Access Token: " TOKEN
fi


# Run initial Linode setup
echo "Running first time configuration dialog..."
linode-cli configure --token


# Gather user input needed for deploy-cloud-runner.sh
echo "Akamai requires a root password to creat a new Linode. In order to adhere to their password requirements, your password will be encoded"
BASE_PASS=$(request_string "Please provide your desired root password for your Linode cloud runner")

AUTHORIZED_KEY=$(request_authorized_key "cloud-runner_rsa")


# Check if the user wants to add any additional stackscripts to run on deployment.
if request_confirmation "Would you like to include any additional scripts to run on your linode's first boot?"; then
    declare -a STACK_SCRIPTS
    while true; do
        STACK_SCRIPT=$(request_filepath "Please provide a script file to run when your linode is first created.")
        STACK_SCRIPTS+=("$STACK_SCRIPT")
        if ! request_confirmation "Would you like to include another script?"; then
            break
        fi
    done

    for SCRIPT in "${STACK_SCRIPTS[@]}"; do
        cp "$SCRIPT" "$STACKSCRIPT_DIR"
    done
fi

# Write the configuration info disk
mkdir -p "$CONF_DIR"
rm -rf "$CONF_FILE"
echo -e "LINODE_TOKEN=\"$TOKEN\"" >> "$CONF_FILE" 
echo -e "LINODE_ROOT_PASS=\"$BASE_PASS\"" >> "$CONF_FILE"
if var_has_value "$AUTHORIZED_KEY"; then
    echo -e "LINODE_AUTHORIZED_KEY=\"$AUTHORIZED_KEY\"" >> "$CONF_FILE"
fi
chmod 600 "$CONF_FILE"



# Check if install was successfull
if command_exists linode-cli && file_exists "$CONF_FILE"; then
    print_success "Linode-CLI successfully installed"
    
else
    print_error "An problem occurred while installing Linode-CLI"
    exit 1
fi
