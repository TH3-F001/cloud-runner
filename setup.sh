#!/bin/bash

# Initialize file and directory variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
VENV_DIR="$HOME/.local/pipx/venvs/linode-cli/"
CONF_DIR="$HOME/.config/cloud-runner"
MASTER_STACKSCRIPT="$CONF_DIR/cloud-runner-stackscript.sh"
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


# Run initial Linode setup
echo "Running first time configuration dialog..."
linode-cli configure --token


# Gather user input needed for deploy-cloud-runner.sh
echo "Akamai requires a root password for your new Linode. In order to adhere to their password requirements, your password will be encoded"
BASE_PASS=$(request_string "Please provide your desired root password for your Linode cloud runner")
HOME_TO_CLOUD_AUTH_KEY=$(generate_ssh_key "$HOME/.ssh/cloudrunner-to-cloud_rsa")
CLOUD_TO_HOME_AUTH_KEY=$(generate_ssh_key "$HOME/.ssh/cloudrunner-to-home_rsa")
SSH_PORT=$(request_port_number "Which Public facing SSH port should cloud-runner send output to?")
PUB_IP=$(curl ipinfo.io/ip)

# Gather User supplied dependencies.
echo "Cloud-Runner allows you to specify dependencies to install on boot as long as they exist in your default image's package manager"
if request_confirmation "Would You like to install any additional dependencies on your linode's first boot?"; then
    read -rp "Enter the list of dependencies (separated by spaces): " USER_DEPS
fi


# Write the configuration info disk
echo "Saving Configuration..."
rm -rf "$CONF_DIR"
mkdir -p "$CONF_DIR"
touch "$CONF_FILE"

echo -e "CLOUDRUNNER_ROOT_PASS=\"$(echo $BASE_PASS | sha1sum)\"" > "$CONF_FILE"
echo -e "HOME_TO_CLOUD_KEY=\"$HOME_TO_CLOUD_AUTH_KEY\"" >> "$CONF_FILE"
echo -e "CLOUD_TO_HOME_KEY=\"$CLOUD_TO_HOME_AUTH_KEY\"" >> "$CONF_FILE"
echo -e "SSH_PORT=\"$SSH_PORT\"" >>$CONF_FILE
echo -e "PUB_IP=\"$PUB_IP\"" >>$CONF_FILE


chmod 600 "$CONF_FILE"


# Move the contents of the project to CONF_DIR
echo "Moving Scripts to .config"
cp -r "$SCRIPT_DIR/libraries" "$CONF_DIR/"
cp "$SCRIPT_DIR"/*.sh "$CONF_DIR/"
# mkdir -p "$CONF_DIR/access"
# cp "$HOME/.ssh/cloudrunner*" "$CONF_DIR/access/"


# Create a quick linode to determine the default Image ID for the account then destroy it
echo "Creating a small linode to grab default image from..."
linode-cli linodes create --type "g6-standard-1" --root_pass "\"$(encode_password $BASE_PASS)\"" --label "Cloud-Tester"
DEFAULT_IMAGE=$(get_linode_image "Cloud-Tester")
TMP_IMG_ID=$(get_linode_id "Cloud-Tester")
echo "Deleting temporary linode..."
if ! linode-cli linodes delete "$TMP_IMG_ID"; then
    echo "ERROR: Linode created but not deleted. Please manually delete!!!"
fi
echo -e "CLOUDRUNNER_DEFAULT_IMAGE=\"$DEFAULT_IMAGE\"" >> "$CONF_FILE"


# Add user dependencies to existing dependencies in the stack script
echo "Adding Dependencies to the Master Stackscript"
IFS=' ' read -r -a USER_DEPS_ARRAY <<< "$USER_DEPS"
DEPS_STRING=$(printf " \"%s\"" "${USER_DEPS_ARRAY[@]}")
DEPS_STRING=${DEPS_STRING:1}
sed -i "s/# Placeholder for user dependencies/DEPENDENCIES+=($DEPS_STRING)/" "$MASTER_STACKSCRIPT"


# Install sshd if needed 
if ! type sshd; then
    if ! install_packages sshd; then
        echo "Failed to Install sshd. Please install, enable, and allow pubkey authentication"
    fi
fi

# Allow Pubkey Authentication
sudo sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
sudo sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null

# Enable sshd if it isnt already enabled, restart it if it is
if ! systemctl is-enabled sshd &> /dev/null; then
    sudo systemctl enable sshd
    sudo systemctl start sshd
    if ! sudo systemctl status sshd; then
        echo "An error occurred while enabling sshd. please investigate and enable"
    fi
else
    sudo systemctl restart sshd
fi


# Check if install was successfull
if command_exists linode-cli && is_valid_file "$CONF_FILE" && is_valid_file "$SCRIPT_DIR/libraries/bool.lib"; then
    print_success "Linode-CLI successfully installed"  
else
    print_error "An problem occurred while installing Linode-CLI"
    exit 1
fi
