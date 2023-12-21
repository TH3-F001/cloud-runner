#!/bin/bash
LOG=/var/log/stackscript.log
touch $LOG
echo -e "=============[ Beginning Cloud-Runner Deployment ]=============" &>>"$LOG" 

# Stop ssh service to make prevent premature notification of completion
# cloud-runner.sh waits until it can make a successfull ssh connection before continuing
systemctl stop sshd &>>"$LOG"
systemctl stop ssh &>>"$LOG"

#region Create cloud-runner user

echo -e "\n\n\t\t-----[ Beginning User Creation... ]-----" &>>"$LOG" 

# Create cloud-runner and change password
NEW_USER="cloud-runner"
PASSWORD=$(openssl rand -base64 12)
echo -e "\nCreating new user: $NEW_USER." &>>"$LOG"
useradd -m "$NEW_USER" &>>"$LOG"
echo "$NEW_USER:$PASSWORD" | sudo chpasswd &>>"$LOG"

# Create cloud-runner's .ssh directory
USER_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)  # Get the user's home directory
SSH_DIR="$USER_HOME/.ssh"
echo -e "\nCreating $SSH_DIR." &>>"$LOG"

mkdir -p "$SSH_DIR" &>>"$LOG"
chmod 700 "$SSH_DIR" &>>"$LOG"
chown "$NEW_USER":"$NEW_USER" "$SSH_DIR" &>>"$LOG"

# Copy root's authorized keys
echo -e "\nCopying root's authorized_keys." &>>"$LOG"
cp /root/.ssh/authorized_keys "$SSH_DIR" &>>"$LOG"
chmod 600 "$SSH_DIR/authorized_keys" &>>"$LOG"
chown "$NEW_USER":"$NEW_USER" "$SSH_DIR/authorized_keys" &>>"$LOG"

# Give cloud-runner passwordless sudo
echo -e "\nGiving $NEW_USER sudo priviledges." &>>"$LOG"
echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo 
#endregion


#region Create I/O Directories
echo -e "\n\n\t\t-----[ Creating I/O Directories... ]-----" &>>"$LOG"
CLOUDRUNNER_DIR="$USER_HOME/cloud-runner"
INPUT_DIR="$CLOUDRUNNER_DIR/input"
OUTPUT_DIR="$CLOUDRUNNER_DIR/output"

mkdir -p "$CLOUDRUNNER_DIR" "$INPUT_DIR" "$OUTPUT_DIR" &>>"$LOG"
chmod -R 777 "$CLOUDRUNNER_DIR" &>>"$LOG"
#endregion


#region Install Dependencies

echo -e "\n\n\t\t-----[ Installing Dependencies... ]-----" &>>"$LOG"

# Declare Dependencies
declare -a DEPENDENCIES=(
    "jq"
    "go"
    "golang"
    "sshfs"
)

# user supplied dependencies are added to DEPENDENCIES using sed and the line below:
# Placeholder for user dependencies

# Install functions
install_and_log() {
    local pkg=$1
    local install_cmd=$2

    if ! $install_cmd "$pkg"; then
        echo "Failed to install $pkg" &>> "$LOG"
    fi
}

install_apt() {
    apt-get update
    apt-get upgrade -y
    for pkg in "${DEPENDENCIES[@]}"; do
        install_and_log "$pkg" "apt-get install -y"
    done
}

install_yum() {
    yum makecache
    yum update -y
    for pkg in "${DEPENDENCIES[@]}"; do
        install_and_log "$pkg" "yum install -y"
    done
}

install_dnf() {
    dnf makecache
    dnf upgrade -y
    for pkg in "${DEPENDENCIES[@]}"; do
        install_and_log "$pkg" "dnf install -y"
    done
}

install_pacman() {
    pacman -Syu --noconfirm
    for pkg in "${DEPENDENCIES[@]}"; do
        install_and_log "$pkg" "pacman -S --noconfirm"
    done
}

install_emerge() {
    emerge --sync
    emerge --update --deep --newuse @world
    for pkg in "${DEPENDENCIES[@]}"; do
        install_and_log "$pkg" "emerge"
    done
}

# Check which PkgMgr is being used and install deps with it
if command -v apt-get &>/dev/null; then
    echo "Installing dependencies with apt-get (Debian/Ubuntu)" &>> "$LOG"
    install_apt
elif command -v yum &>/dev/null; then
    echo "Installing dependencies with yum (CentOS/RHEL)" &>> "$LOG"
    install_yum
elif command -v dnf &>/dev/null; then
    echo "Installing dependencies with dnf (Fedora)" &>> "$LOG"
    install_dnf
elif command -v pacman &>/dev/null; then
    echo "Installing dependencies with pacman (Arch Linux)" &>> "$LOG"
    install_pacman
elif command -v emerge &>/dev/null; then
    echo "Installing dependencies with emerge (Gentoo)" &>> "$LOG"
    install_emerge
else
    echo "No recognized package manager found." &>> "$LOG"
fi
#endregion


#region Global SSH configuration

echo -e "\n\n\t\t-----[ Beginning SSH Configuration... ]-----" &>>"$LOG"
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup the original SSHD configuration file
echo "Backing up $SSHD_CONFIG." &>>"$LOG"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak" &>>"$LOG"

# Enable public key authentication
echo "Enabling PubkeyAuthentication." &>>"$LOG"
sed -i 's/^#PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSHD_CONFIG" &>>"$LOG"
sed -i 's/^PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSHD_CONFIG" &>>"$LOG"

# Disable password authentication
echo "Disabling Password Authentication." &>>"$LOG"
sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG" &>>"$LOG"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG" &>>"$LOG"

# Disable root login
echo "Disabling Root Login." &>>"$LOG"
sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG" &>>"$LOG"
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG" &>>"$LOG"

# Restart SSH service to apply changes
echo "Checking Which SSH Service to Enable." &>>"$LOG"
if systemctl list-units --type=service | grep -q 'sshd'; then
    echo "Enabling and starting 'sshd' service..." &>>"$LOG"
    systemctl start sshd &>>"$LOG"
    systemctl enable sshd &>>"$LOG"
elif systemctl list-units --type=service | grep -q 'ssh'; then
    echo "Enabling and starting 'ssh' service..." &>>"$LOG"
    systemctl start ssh &>>"$LOG"
    systemctl enable ssh &>>"$LOG"
else
    echo "SSH service not found." &>>"$LOG"
fi
sleep 5
#endregion


#region Signal that Deployment has been completed
echo -e  "\n\n\t\t=============[ Cloud-Runner Deployment Completed! ]============="
cp "$LOG" "$OUTPUT_DIR"/
#endregion