#!/bin/bash
 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
CONF_DIR="$HOME/.config/cloud-runner"
CONF_FILE="$CONF_DIR/cloud-reunner.conf"
CLOUDRUNNER_STACKSCRIPT="$CONF_DIR/cloud-runner-stackscript.sh"
SSH_USER="cloud-runner"
SSH_KEY_PATH="$CONF_DIR/access/cloud-runner_rsa"
SSH_PORT=42122
LINODE_LABEL="Cloud-Runner"
STACKSCRIPT_LABEL="$LINODE_LABEL-Script"
USER_SCRIPT=$1

if [ -z $USER_SCRIPT ] || [ ! -f $USER_SCRIPT ]; then
    echo "cloud-runner requires a valid script path as an argument."
    exit 1
fi

source "$LIB_SCRIPT_DIR/cloud-runner.lib"
source "$CONF_FILE"



lin stackscripts delete $(get_stackscript_id $STACKSCRIPT_LABEL)
create_linode_stackscript "$CLOUDRUNNER_STACKSCRIPT" "$STACKSCRIPT_LABEL" "$CLOUDRUNNER_DEFAULT_IMAGE"
lin linodes create --root_pass "$(encode_password $CLOUDRUNNER_ROOT_PASS)" --authorized_keys "$(cat $HOME_TO_CLOUD_KEY)" --label "$LINODE_LABEL" --swap_size 8192 --stackscript_id "$(get_stackscript_id $STACKSCRIPT_LABEL)"
sleep 1
LINODE_IP=$(get_linode_ipv4 "$LINODE_LABEL")


echo "Pinging $LINODE_LABEL at $LINODE_IP until it responds..."
while ! ping -c 1 -W 1 "$LINODE_IP" &> /dev/null; do
    echo "Waiting for $LINODE_IP to respond..."
    sleep 1
done

echo "$LINODE_IP is now responding to ping. Waiting for 5 seconds..."
sleep 5

# Attempt to connect via SSH
echo "Attempting to connect to $LINODE_IP via SSH..."
ssh -i "$SSH_KEY_PATH" "$SSH_USER@$LINODE_IP"


#TODO For some reason SSH key isnt being coipies