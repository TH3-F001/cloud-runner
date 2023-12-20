#!/bin/bash

install_apt() {
    local pkg=$1
    echo "Using apt to install $pkg..."
    sudo apt-get update
    sudo apt-get install -y "$pkg"
}

# Function to install $pkg using yum
install_yum() {
    local pkg=$1
    echo "Using yum to install $pkg..."
    sudo yum install -y "$pkg"
}

# Function to install $pkg using dnf
install_dnf() {
    local pkg=$1
    echo "Using dnf to install $pkg..."
    sudo dnf install -y "$pkg"
}

# Function to install $pkg using zypper
install_zypper() {
    local pkg=$1
    echo "Using zypper to install $pkg..."
    sudo zypper install -y "$pkg"
}

# Function to install $pkg using pacman
install_pacman() {
    local pkg=$1
    echo "Using pacman to install $pkg..."
    sudo pacman -Syu "$pkg" --noconfirm
}


# Define Variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CLOUDRUNNER_DIR=/opt/cloud-runner
LIB_SCRIPT_DIR="$CLOUDRUNNER_DIR/libraries"
LOG="/var/log/cloud-runner.log"


# Initialize Cloud-Runner files
mkdir -p $CLOUDRUNNER_DIR &>>"$LOG"
mkdir -p
touch "$LOG" 


# Declare Argument Variables
# CLOUD_PRIV_KEY="$PRIV_KEY"
# CLOUD_PUB_KEY="$PUB_KEY"
# HOME_SSH_PORT="$SSH_PORT"
# HOME_SSH_IP="$SSH_IP"
# HOME_SSH_USER="$SSH_USER"


# echo "CLOUD_PUB_KEY: $CLOUD_PUB_KEY" &>>"$LOG"
# echo "HOME_SSH_PORT: $HOME_SSH_PORT" &>>"$LOG"
# echo "HOME_SSH_IP: $HOME_SSH_IP" &>>"$LOG"
# echo "HOME_SSH_USER: $HOME_SSH_USER" &>>"$LOG"


# Install git for starters
echo "Installing Git..." &>>"$LOG"
if command -v apt-get > /dev/null 2>&1; then
    install_apt git 2>>"$LOG"
    install_apt openssh-server 2>>"$LOG"
elif command -v yum > /dev/null 2>&1; then
    install_yum git 2>>"$LOG"
    install_yum openssh-server 2>>"$LOG"
elif command -v dnf > /dev/null 2>&1; then
    install_dnf git 2>>"$LOG"
    install_dnf openssh-server 2>>"$LOG"
elif command -v zypper > /dev/null 2>&1; then
    install_zypper git 2>>"$LOG"
    install_zypper openssh-server 2>>"$LOG"
elif command -v pacman > /dev/null 2>&1; then
    install_pacman git 2>>"$LOG"
    install_pacman openssh 2>>"$LOG"
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
# echo "scp -o StrictHostKeyChecking=no -P $HOME_SSH_PORT -i $USER_HOME/.ssh/cloud-runner_rsa   $LOG cloud-runner@$HOME_SSH_IP:/opt/cloud-runner/stackscript.log" &>> "$LOG"
# scp -o StrictHostKeyChecking=no -P $HOME_SSH_PORT -i "$USER_HOME"/.ssh/cloud-runner_rsa "$LOG" cloud-runner@"$HO

# Install Dependencies
declare -a DEPENDENCIES=(
    "jq"
    "go"
    "sshfs"
)

echo "Installing Dependencies..." &>>"$LOG"
# Placeholder for user dependencies
install_packages "${DEPENDENCIES[@]}" &>>"$LOG" 



# Create New User
echo "Creating New User..." &>>"$LOG"
NEW_USER="cloud-runner"
USER_HOME="/home/$NEW_USER"
CLOUDRUNNER_DIR="$USER_HOME/cloud-runner"
INPUT_DIR="$CLOUDRUNNER_DIR/input"
OUTPUT_DIR="$CLOUDRUNNER_DIR/output"

useradd -m -U -s /bin/bash "$NEW_USER" &>>"$LOG"
mkdir -p "$CLOUDRUNNER_DIR" &>>"$LOG"
mkdir -p "$USER_HOME"/.ssh &>>"$LOG"
mkdir -p "$INPUT_DIR"
mkdir -p "$OUTPUT_DIR"
chmod -R 777 $CLOUDRUNNER_DIR

# Generate a random password for the user
echo "Generating Random Password..." &>>"$LOG"
RANDOM_PASS=$(openssl rand -base64 24)
echo "$NEW_USER:$RANDOM_PASS" | chpasswd &>>"$LOG"


#-------------------------------- SSH Configuration --------------------------------#


# Save Homeward bound ssh information to $HOME/cloud-runner
# echo "Copy home variables to user directory" &>>"$LOG"
# echo "$HOME_SSH_PORT" > "$USER_HOME/cloud-runner/home_port"
# echo "$HOME_SSH_IP" > "$USER_HOME/cloud-runner/home_ip"
# echo "$HOME_SSH_USER" > $USER_HOME/cloud-runner/home_user
# chown -R $NEW_USER:$NEW_USER "$USER_HOME/cloud-runner" &>>"$LOG"
# chmod 600 "$USER_HOME"/cloud-runner/* &>>"$LOG"


# Copy Root Authorized Keys to the user's directory
echo "Copying Authorized Keys to New User..." &>>"$LOG"
cp /root/.ssh/authorized_keys "$USER_HOME"/.ssh/ &>>"$LOG"
# echo "$CLOUD_PUB_KEY" >> "$USER_HOME/.ssh/authorized_keys"



# Copy User Supplied SSH keys to users home directory
# echo "Copying rsa keys to new user..." &>>"$LOG"
# echo "$CLOUD_PRIV_KEY" > "$USER_HOME"/.ssh/cloud-runner_rsa 
# echo "$CLOUD_PUB_KEY" > "$USER_HOME"/.ssh/cloud-runner_rsa.pub
chown -R "$NEW_USER":"$NEW_USER" "$USER_HOME"/.ssh &>>"$LOG"


# Assign proper permissions to .ssh directory
echo "Updating Permissions for users .ssh directory..." &>>"$LOG"
chmod 700 "$USER_HOME"/.ssh &>>"$LOG"
chmod 600 "$USER_HOME"/.ssh/authorized_keys &>>"$LOG"
# chmod 644 "$USER_HOME"/.ssh/cloud-runner_rsa.pub &>>"$LOG"
# chmod 600 "$USER_HOME"/.ssh/cloud-runner_rsa &>>"$LOG"


# Set up SSHFS


# Configuring sshd_conf
echo "Configuring sshd_conf..." &>>"$LOG"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &>>"$LOG"
# Remove existing settings
sed -i '/^#PermitRootLogin/d' /etc/ssh/sshd_config &>>"$LOG"
sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config &>>"$LOG"
sed -i '/^#PasswordAuthentication/d' /etc/ssh/sshd_config &>>"$LOG"
sed -i '/^PasswordAuthentication/d' /etc/ssh/sshd_config &>>"$LOG"
sed -i '/^#PubkeyAuthentication/d' /etc/ssh/sshd_config &>>"$LOG"
sed -i '/^PubkeyAuthentication/d' /etc/ssh/sshd_config &>>"$LOG"

# Append new settings
echo "PermitRootLogin no" >> /etc/ssh/sshd_config 
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config 
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config 

# Enable sshd
echo "Starting sshd..." &>>"$LOG"
systemctl start sshd &>>"$LOG"
systemctl restart sshd &>>"$LOG"
systemctl enable sshd &>>"$LOG"
systemctl start ssh &>>"$LOG"
systemctl restart ssh &>>"$LOG"
systemctl enable ssh &>>"$LOG"
#-------------------------------- End SSH Configuration --------------------------------#


# Allow for passwordless sudo
# echo "Adding new user to the sudoers file..." &>>"$LOG"
# echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 
echo "Adding new user to the sudoers file..." &>>"$LOG"
echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo



# echo "scp -o StrictHostKeyChecking=no -P $HOME_SSH_PORT -i $USER_HOME/.ssh/cloud-runner_rsa   $LOG cloud-runner@$HOME_SSH_IP:/opt/cloud-runner/stackscript.log" &>> "$LOG"
# scp -o StrictHostKeyChecking=no -P $HOME_SSH_PORT -i "$USER_HOME"/.ssh/cloud-runner_rsa "$LOG" cloud-runner@"$HOME_SSH_IP":/opt/cloud-runner/stackscript.log &>> "$LOG"
cp $LOG