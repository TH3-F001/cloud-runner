#!/bin/bash
 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
CONF_DIR="$HOME/.config/cloud-runner"
CONF_FILE="$CONF_DIR/cloud-reunner.conf"
CLOUDRUNNER_STACKSCRIPT="$CONF_DIR/cloud-runner-stackscript.sh"
SSH_USER="cloud-runner"
LINODE_LABEL="Cloud-Runner"
FIREWALL_LABEL="Cloud-Runner_Firewall"
STACKSCRIPT_LABEL="$LINODE_LABEL-Script"
SHARED_DIR="/opt/cloud-runner"
USER_SCRIPT=$1


# Ensure a file is supplied as an argument
if [ -z $USER_SCRIPT ] || [ ! -f $USER_SCRIPT ]; then
    echo "cloud-runner requires a valid script path as an argument."
    exit 1
fi


# Source Libraries
source "$LIB_SCRIPT_DIR/cloud-runner.lib"
source "$CONF_FILE"


# Upload stackscript to linode
echo "Uploading Cloud-Runner StackScript..."
lin stackscripts delete $(get_stackscript_id $STACKSCRIPT_LABEL) >/dev/null
create_linode_stackscript "$CLOUDRUNNER_STACKSCRIPT" "$STACKSCRIPT_LABEL" "$CLOUDRUNNER_DEFAULT_IMAGE" >/dev/null


# Build Stackscript arguments
echo -e "\nBuilding StackScript Arguments..."
PRIV_KEY_DATA=$(cat "$CLOUD_TO_HOME_KEY")
PUB_KEY_DATA=$(cat "$CLOUD_TO_HOME_KEY.pub")
STACKSCRIPT_DATA=$(jq -n \
                  --arg privKey "$PRIV_KEY_DATA" \
                  --arg pubKey "$PUB_KEY_DATA" \
                  --arg sshPort "$SSH_PORT" \
                  --arg sshIp "$PUB_IP" \
                  --arg sshUser "$(whoami)" \
                  '{PRIV_KEY: $privKey, PUB_KEY: $pubKey, SSH_PORT: $sshPort, SSH_IP: $sshIp, SSH_USER: $sshUser}')


# Building Linode
echo -e "\nCreating New Cloud-Runner Linode..."
lin linodes create \
    --root_pass "$(encode_password $CLOUDRUNNER_ROOT_PASS)" \
    --authorized_keys "$(cat $HOME_TO_CLOUD_KEY.pub)" \
    --label "$LINODE_LABEL" \
    --swap_size 8192 \
    --stackscript_id "$(get_stackscript_id $STACKSCRIPT_LABEL)" \
    --stackscript_data "$STACKSCRIPT_DATA" >/dev/null
sleep 1

# Get Linode's IP Address
echo -e "\nGetting Linode's IP Address..."
LINODE_IP=$(get_linode_ipv4 "$LINODE_LABEL")


# Wait for Linode's IP to respond
echo -e "\nWaiting for $LINODE_IP to respond..."
while ! ping -c 1 -W 1 "$LINODE_IP" &> /dev/null; do
    sleep 2
done


# Wait for linode to send stackscript log denoting successfull deployment
echo -e "\n$LINODE_IP is now responding to ping. Waiting for linode to complete stackscript..."
rm -f "$SHARED_DIR"/*.log
while true; do
    if ls "$SHARED_DIR"/*.log 1> /dev/null 2>&1; then
        echo "Log file found in $SHARED_DIR."
        break
    else
        sleep 2
    fi
done
echo -e "\n\n\t\t---[ Linode has been successfully Deployed! ]---"


# # Attempt to connect via SSH
# echo -e "\n Attempting to connect to $LINODE_IP via SSH..."
# if ssh -o StrictHostKeyChecking=no -T -i "$HOME_TO_CLOUD_KEY" "$SSH_USER@$LINODE_IP"  "echo 'SSH connection successful' > /home/$SSH_USER/.ssh-test.txt"; then
#     echo -e "\nSSH Connection Successful: Time to send your script!"
#     ssh -o StrictHostKeyChecking=no -i "$HOME_TO_CLOUD_KEY" "$SSH_USER@$LINODE_IP" 
# else
#     echo -e "\nSSH Connection Failed: Unable to connect or write to the test file."
#     echo "ssh -o StrictHostKeyChecking=no -i $HOME_TO_CLOUD_KEY $SSH_USER@$LINODE_IP "
#     echo "$(encode_password $CLOUDRUNNER_ROOT_PASS)"
# fi



lin linodes delete $(get_linode_id $LINODE_LABEL)
lin linodes ls


