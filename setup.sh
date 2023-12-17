#!/bin/bash

# Initialize file and directory variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
VENV_DIR="$HOME/.local/pipx/venvs/linode-cli/"
CONF_DIR="$HOME/.config/cloud-runner"
MASTER_STACKSCRIPT="$CONF_DIR/cloud-runner-stackscript.sh"
CONF_FILE="$CONF_DIR/cloud-runner.conf"

# Initial sudo request to cache credentials for the remainder of the script
echo -e "sudo access is required to set up cloud-runner."
sudo echo -e "\nStarting Cloud-Runner Configuration..."

#region Install and source n00b-bash libraries

echo -e "\n📦 Installing n00b-bash libs..."
TMP_DIR="/tmp/n00b-bash"
rm -rf $TMP_DIR 2>/dev/null
git clone https://github.com/TH3-F001/n00b-bash.git "$TMP_DIR" &>/dev/null
mkdir -p "$LIB_SCRIPT_DIR"
cp "$TMP_DIR"/*.lib "$LIB_SCRIPT_DIR"

for LIB_FILE in "$LIB_SCRIPT_DIR"/*\.lib; do
    source "$LIB_FILE"
done
#endregion


#region Install nc

if ! command_exists nc; then 
    install_packages nc
fi
#endregion

#region Linode Configuration

# Install Linode
echo -e "\nChecking If linode-cli is installed..."
if ! command_exists linode-cli; then
    echo -e "\t📦 Installing linode-cli..."
    pipx install linode-cli
    "$VENV_DIR/bin/python3" -m pip install boto3
else
    echo -e "\t✨ Linode-CLI is already installed!"
fi

# Run initial Linode setup
echo -e "\nRunning first time configuration dialog...\n\n"
linode-cli configure --token
#endregion


#region Gather user input

echo -e "\nAkamai requires a root password for your new Linode. In order to adhere to their password requirements, your password will be encoded.\n"
BASE_PASS=$(request_string "Please provide your desired root password for your Linode cloud runner")
echo -e "\nCloud-Runner requires the you have an open SSH port to the internet so it can securely transfer results."
SSH_PORT=$(request_port_number "Which external SSH port should your linode report back to?")
echo -e "\t[ DONT FORGET TO OPEN $SSH_PORT ON YOUR ROUTER'S FIREWALL! ]"

# Gather User supplied dependencies.
echo -e "\nCloud-Runner allows you to specify dependencies to install on boot as long as they exist in your default image's package manager"
if request_confirmation "Would You like to install any additional dependencies on your linode's first boot?"; then
    echo -e "\nEnter the list of dependencies (separated by spaces):"
    read -rp "> " USER_DEPS
fi
#endregion


#region SSH configuration

# Install sshd if needed
echo -e "\nChecking that sshd exists..."
if ! type sshd; then
    echo -e "sshd doesnt exist"
    if ! install_packages sshd; then
        echo -e "\nFailed to Install sshd. Please install, enable, and allow pubkey authentication"
    fi
fi

# Create SSH keys for both inbound and outbound connections
HOME_TO_CLOUD_AUTH_KEY=$(generate_ssh_key "$HOME/.ssh/cloudrunner-to-cloud_rsa" 2>/dev/null) 
CLOUD_TO_HOME_AUTH_KEY=$(generate_ssh_key "$HOME/.ssh/cloudrunner-to-home_rsa" 2>/dev/null)


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
#endregion


#region Create firewall (possibly not needed)

# Create a linode firewall with open user-supplied ssh port
# FIREWALL_LABEL="Cloud-Runner_Firewall"
# linode-cli firewalls delete $(get_firewall_id "$FIREWALL_LABEL" 2>/dev/null) 2>/dev/null
# linode-cli firewalls create \
#     --label "$FIREWALL_LABEL" \
#     --rules.inbound_policy DROP \
#     --rules.outbound_policy ACCEPT \
#     --rules.inbound '[{"action": "ACCEPT", "protocol": "ICMP", "addresses": {"ipv4": ["0.0.0.0/0"], "ipv6": ["::/0"]}}, {"action": "ACCEPT", "ports": "'"22"'", "protocol": "TCP", "addresses": {"ipv4": ["0.0.0.0/0"], "ipv6": ["::/0"]}}]' \
#     --rules.outbound '[{"action": "ACCEPT", "ports": "'"$SSH_PORT"'", "protocol": "TCP", "addresses": {"ipv4": ["0.0.0.0/0"], "ipv6": ["::/0"]}}]'
#endregion


#region Find out public IP Address

services=(
    "https://api.ipify.org"
    "https://ifconfig.me"
    "https://ipinfo.io/ip"
    "https://icanhazip.com"
    "https://checkip.amazonaws.com"
)
for service in "${services[@]}"; do
    PUB_IP=$(curl -s $service)
    if [[ -n "$PUB_IP" ]] && is_valid_ip "$PUB_IP"; then
        break
    fi
done
#endregion


#region Determine default Linode Image ID

# Create a quick linode to determine the default Image ID for the account then destroy it
echo -e "\nCreating a small linode to grab default image from..."
linode-cli linodes create --type "g6-standard-1" --root_pass "\"$(encode_password $BASE_PASS)\"" --label "Cloud-Tester"
DEFAULT_IMAGE=$(get_linode_image "Cloud-Tester")
TMP_IMG_ID=$(get_linode_id "Cloud-Tester")
echo -e "\nDeleting temporary linode..."
if ! linode-cli linodes delete "$TMP_IMG_ID"; then
    echo -e "\nERROR: Linode created but not deleted. Please manually delete!!!"
fi
#endregion


#region Save configuration info to $CONF_FILE and move Scripts into .config

echo -e "\nSaving Configuration..."
rm -rf "$CONF_DIR"
mkdir -p "$CONF_DIR"
touch "$CONF_FILE"

echo -e "CLOUDRUNNER_ROOT_PASS=\"$(echo $BASE_PASS | sha1sum)\"" > "$CONF_FILE"
echo -e "HOME_TO_CLOUD_KEY=\"$HOME_TO_CLOUD_AUTH_KEY\"" >> "$CONF_FILE"
echo -e "CLOUD_TO_HOME_KEY=\"$CLOUD_TO_HOME_AUTH_KEY\"" >> "$CONF_FILE"
echo -e "SSH_PORT=\"$SSH_PORT\"" >>$CONF_FILE
echo -e "PUB_IP=\"$PUB_IP\"" >>$CONF_FILE
echo -e "CLOUDRUNNER_DEFAULT_IMAGE=\"$DEFAULT_IMAGE\"" >> "$CONF_FILE"
REQUIRED_VARIABLES=(CLOUDRUNNER_ROOT_PASS HOME_TO_CLOUD_KEY CLOUD_TO_HOME_KEY SSH_PORT PUB_IP CLOUDRUNNER_DEFAULT_IMAGE)
chmod 600 "$CONF_FILE"

# Move the contents of the project to CONF_DIR
echo -e "\nMoving Scripts to .config"
cp -r "$SCRIPT_DIR/libraries" "$CONF_DIR/"
cp "$SCRIPT_DIR"/*.sh "$CONF_DIR/"
#endregion


#region Alter Stackscript file

# Add user supplied dependencies to existing dependencies in the stack script
echo -e "\nAdding Dependencies to the Master Stackscript"
IFS=' ' read -r -a USER_DEPS_ARRAY <<< "$USER_DEPS"
DEPS_STRING=$(printf " \"%s\"" "${USER_DEPS_ARRAY[@]}")
DEPS_STRING=${DEPS_STRING:1}
sed -i "s/# Placeholder for user dependencies/DEPENDENCIES+=($DEPS_STRING)/" "$MASTER_STACKSCRIPT"
#endregion


#region Set up cloud-runner user

# The cloud-runner user is used to sandbox ssh configurations from the Linode to your machine
# and limit permissions in the event that your linode is somehow compromised
NEW_USER="cloud-runner"
NEW_USER_HOME="/home/$NEW_USER/"
NEW_USER_SSH_DIR="$NEW_USER_HOME/.ssh"
SHARED_GROUP="crunner"
SHARED_DIR="$HOME/cloud-runner"

# Create user and add to group in order to share a folder
sudo useradd -m "$NEW_USER"
sudo groupadd "$SHARED_GROUP"
sudo usermod -aG "$SHARED_GROUP" "$NEW_USER"
sudo usermod -aG "$SHARED_GROUP" "$(whoami)"

# Initialize user's .ssh directory
sudo mkdir -p "$NEW_USER_SSH_DIR"
cat "$CLOUD_TO_HOME_AUTH_KEY.pub" | sudo tee "$NEW_USER_SSH_DIR/authorized_keys" > /dev/null
sudo chown -R "$NEW_USER":"$NEW_USER" $NEW_USER_HOME
sudo chmod 700 "$NEW_USER_SSH_DIR"
sudo chmod 600 "$NEW_USER_SSH_DIR/authorized_keys"

# Initialize shared file for cloud-runner output
mkdir -p "$SHARED_DIR"
sudo chown -R :"$SHARED_GROUP" "$SHARED_DIR"
sudo chmod -R g+w "$SHARED_DIR"
sudo chmod g+s "$SHARED_DIR"
#endregion


#region Check if install was successfull

command_exists() {
    type "$1" &> /dev/null
}

# Function to check if a file is valid
is_valid_file() {
    [[ -f "$1" ]]
}

are_variables_set() {
    for var in "${REQUIRED_VARIABLES[@]}"; do
        if [ -z "${!var}" ]; then
            return 1
        fi
    done
    return 0
}

checklist=()

# Check if user exists
if id "$NEW_USER" &>/dev/null; then
    checklist+=("User '$NEW_USER' exists ✔️")
else
    checklist+=("User '$NEW_USER' does not exist ❌")
fi

# Check if group exists
if getent group "$SHARED_GROUP" &>/dev/null; then
    checklist+=("Group '$SHARED_GROUP' exists ✔️")
else
    checklist+=("Group '$SHARED_GROUP' does not exist ❌")
fi

# Check if shared directory exists, belongs to the shared group, and has GID permissions set
if [[ -d "$SHARED_DIR" && $(stat -c "%G" "$SHARED_DIR") == "$SHARED_GROUP" && $(stat -c "%A" "$SHARED_DIR") == *s* ]]; then
    checklist+=("Shared directory '$SHARED_DIR' exists, belongs to group '$SHARED_GROUP' and has GID permissions ✔️")
else
    checklist+=("Shared directory '$SHARED_DIR' must belong to $SHARED_GROUP and have GID permissions ❌")
fi

# Check if CONF_FILE is a valid file and required variables are set
if is_valid_file "$CONF_FILE"; then
    source "$CONF_FILE"
    if are_variables_set; then
        checklist+=("Configuration file '$CONF_FILE' is valid and all required variables are set ✔️")
    else
        checklist+=("Configuration file '$CONF_FILE' is missing required variables ❌")
    fi
else
    checklist+=("Configuration file '$CONF_FILE' is not valid ❌")
fi

# Check if the libraries folder was copied successfully
if is_valid_file "$SCRIPT_DIR/libraries/bool.lib"; then
    checklist+=("File '$SCRIPT_DIR/libraries/bool.lib' is valid ✔️")
else
    checklist+=("File '$SCRIPT_DIR/libraries/bool.lib' is not valid ❌")
fi

# Check for successfull inbound SSH connection

if port_is_open "$PUB_IP" "$SSH_PORT"; then
    checklist+=("SSH connection to $PUB_IP over port $SSH_PORT is open ✔️")
else
    checklist+=("SSH connection to $PUB_IP over port $SSH_PORT is not open or reachable ❌")
fi

# Check if linode-cli command exists
if command_exists linode-cli; then
    checklist+=("Command 'linode-cli' exists ✔️")
else
    checklist+=("Command 'linode-cli' does not exist ❌")
fi

# Print checklist
echo -e "\nInstallation Checklist:"
for item in "${checklist[@]}"; do
    echo -e "$item"
done

# Exit if any checks failed
for item in "${checklist[@]}"; do
    if [[ "$item" == *❌ ]]; then
        exit 1
    fi
done

echo "All checks passed successfully."