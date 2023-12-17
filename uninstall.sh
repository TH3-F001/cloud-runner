#!/bin/bash

# Initialize file and directory variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
CONF_DIR="$HOME/.config/cloud-runner"
CONF_FILE="$CONF_DIR/cloud-runner.conf"
CLOUD_RUNNER_USER="cloud-runner"
SHARED_GROUP="crunner"
SHARED_DIR=$HOME/cloud-runner
CURRENT_USER=$(whoami)
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"

# Initial sudo request to cache credentials for the remainder of the script
echo -e "sudo access is required to uninstall cloud-runner."
sudo echo -e "\nUninstalling Cloud-Runner..."

source $CONF_FILE

# Take ownership of $SHARED_DIR
echo -e "\nTaking ownership of $SHARED_DIR"
sudo chown "$CURRENT_USER":"$CURRENT_USER" "$SHARED_DIR"
chmod g-s "$SHARED_DIR"

# Remove cloud-runner user and group
echo -e "\nDeleting cloud-runner user and group"
sudo userdel -r "$CLOUD_RUNNER_USER"
sudo groupdel "$SHARED_GROUP"

# Delete SSH keys
echo -e "\nDeleting Cloud-Runner ssh keys"
grep -vF "$(cat $CLOUD_TO_HOME_KEY.pub)" "$AUTHORIZED_KEYS" > temp && mv temp "$AUTHORIZED_KEYS"
rm "$HOME_TO_CLOUD_KEY"
rm "$HOME_TO_CLOUD_KEY.pub"
rm "$CLOUD_TO_HOME_KEY"
rm "$CLOUD_TO_HOME_KEY.pub"

# Delete the install/config directory
echo -e "Deleting $CONF_DIR"
rm -rf "$CONF_DIR"

echo -e "cloud-runner successfully uninstalled."