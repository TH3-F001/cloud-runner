#!/bin/bash
LOG=/var/log/stackscript.log
touch $LOG


#region Create cloud-runner user

echo "Beginning User Creation..." &>>"$LOG" 

# Create cloud-runner and change password
NEW_USER="cloud-runner"
PASSWORD=$(openssl rand -base64 12)
echo "Creating new user: $NEW_USER." &>>"$LOG"
useradd -m "$NEW_USER" &>>"$LOG"
echo "$NEW_USER:$PASSWORD" | sudo chpasswd &>>"$LOG"

# Create cloud-runner's .ssh directory
USER_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)  # Get the user's home directory
SSH_DIR="$USER_HOME/.ssh"
echo "Creating $SSH_DIR." &>>"$LOG"

mkdir -p "$SSH_DIR" &>>"$LOG"
chmod 700 "$SSH_DIR" &>>"$LOG"
chown "$NEW_USER":"$NEW_USER" "$SSH_DIR" &>>"$LOG"

# Copy root's authorized keys
echo "Copying root's authorized_keys" &>>"$LOG"
cp /root/.ssh/authorized_keys "$SSH_DIR" &>>"$LOG"
chmod 600 "$SSH_DIR/authorized_keys" &>>"$LOG"
chown "$NEW_USER":"$NEW_USER" "$SSH_DIR/authorized_keys" &>>"$LOG"

# Give cloud-runner passwordless sudo
echo "giving $NEW_USER sudo priviledges." &>>"$LOG"
echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo 
#endregion


#region Create I/O Directories



#region Global SSH configuration

echo "Beginning SSH Configuration..." &>>"$LOG"
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
    sudo systemctl restart sshd &>>"$LOG"
    sudo systemctl enable sshd &>>"$LOG"
elif systemctl list-units --type=service | grep -q 'ssh'; then
    echo "Enabling and starting 'ssh' service..." &>>"$LOG"
    sudo systemctl restart ssh &>>"$LOG"
    sudo systemctl enable ssh &>>"$LOG"
else
    echo "SSH service not found." &>>"$LOG"
fi
#endregion
