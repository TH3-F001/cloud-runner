#!/bin/bash

install_git_apt() {
    echo "Using apt to install git..."
    sudo apt-get update
    sudo apt-get install -y git
}

# Function to install git using yum
install_git_yum() {
    echo "Using yum to install git..."
    sudo yum install -y git
}

# Function to install git using dnf
install_git_dnf() {
    echo "Using dnf to install git..."
    sudo dnf install -y git
}

# Function to install git using zypper
install_git_zypper() {
    echo "Using zypper to install git..."
    sudo zypper install -y git
}

# Function to install git using pacman
install_git_pacman() {
    echo "Using pacman to install git..."
    sudo pacman -Syu git --noconfirm
}


# Define Variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CLOUDRUNNER_DIR=/opt/cloud-runner
LIB_SCRIPT_DIR="$CLOUDRUNNER_DIR/libraries"
LOG="/var/log/cloud-runner.log"


# Initialize Cloud-Runner files
mkdir -p $CLOUDRUNNER_DIR 
touch "$LOG"

# Declare Argument Variables
CLOUD_PRIV_KEY="$PRIV_KEY"
CLOUD_PUB_KEY="$PUB_KEY"
# Install Initial Dependencies 
echo "Installing Initial Dependencies..." &>>"$LOG"

if command -v apt-get > /dev/null 2>&1; then
    install_git_apt &>>"$LOG"
elif command -v yum > /dev/null 2>&1; then
    install_git_yum &>>"$LOG"
elif command -v dnf > /dev/null 2>&1; then
    install_git_dnf &>>"$LOG"
elif command -v zypper > /dev/null 2>&1; then
    install_git_zypper &>>"$LOG"
elif command -v pacman > /dev/null 2>&1; then
    install_git_pacman &>>"$LOG"
else
    echo "No recognized package manager found." &>>"$LOG"
    exit 1
fi

#Install N00b-Bash Libraries
echo -e "\nInstalling n00b-bash libs..." &>>"$LOG"
TMP_DIR="/tmp/n00b-bash"
rm -rf $TMP_DIR &>>"$LOG"
git clone https://github.com/TH3-F001/n00b-bash.git "$TMP_DIR" &>>"$LOG"
mkdir -p "$LIB_SCRIPT_DIR" &>>"$LOG"
cp "$TMP_DIR"/*.lib "$LIB_SCRIPT_DIR" &>>"$LOG"

for LIB_FILE in "$LIB_SCRIPT_DIR"/*\.lib; do
    source "$LIB_FILE"
done


# Create New User
echo "Creating New User..." &>>"$LOG"
NEW_USER="cloud-runner"
USER_HOME="/home/$NEW_USER" 
useradd -m -U -s /bin/bash "$NEW_USER" &>>"$LOG"


# Generate a random password for the user
echo "Generating Random Password..." &>>"$LOG"
RANDOM_PASS=$(openssl rand -base64 24)
echo "$NEW_USER:$RANDOM_PASS" | chpasswd &>>"$LOG"


# Write SSH Keys to disk
echo "$CLOUD_PRIV_KEY" > "$USER_HOME"/.ssh/cloud-runner_rsa 
echo "$CLOUD_PUB_KEY" > "$USER_HOME"/.ssh/cloud-runner_rsa.pub


# Copy Root Authorized Keys to the user's directory
echo "Copying Authorized Keys to New User..." &>>"$LOG"
mkdir -p "$USER_HOME"/.ssh &>>"$LOG"
cp /root/.ssh/authorized_keys "$USER_HOME"/.ssh/ &>>"$LOG"
chown -R "$NEW_USER":"$NEW_USER" "$USER_HOME"/.ssh &>>"$LOG"


# Assign proper permissions to .ssh directory
chmod 700 "$USER_HOME"/.ssh &>>"$LOG"
chmod 600 "$USER_HOME"/.ssh/authorized_keys &>>"$LOG"
chmod 644 "$USER_HOME"/.ssh/cloud-runner_rsa.pub
chmod 600 "$USER_HOME"/.ssh/cloud-runner_rsa

# Edit sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#Port 22/Port 42122/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config


# Allow for passwordless sudo
echo "Adding new user to the sudoers file..." &>>"$LOG"
echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 

declare -a DEPENDENCIES=(
    "jq"
    "go"
)

# Install Dependencies
echo "Installing Dependencies..." &>>"$LOG"
# Placeholder for user dependencies
install_packages "${DEPENDENCIES[@]}" &>>"$LOG"

