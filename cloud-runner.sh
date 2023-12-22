#!/bin/bash

#region Primary variable initialization
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
CONF_DIR="$HOME/.config/cloud-runner"
CONF_FILE="$CONF_DIR/cloud-runner.conf"
CLOUDRUNNER_STACKSCRIPT="$CONF_DIR/cloud-runner-stackscript.sh"
SSH_USER="cloud-runner"
LINODE_LABEL="Cloud-Runner"
FIREWALL_LABEL="Cloud-Runner_Firewall"
STACKSCRIPT_LABEL="$LINODE_LABEL-Script"
DEPLOYED_STRING="[ Cloud-Runner Deployment Completed! ]"

# Source Libraries
source "$LIB_SCRIPT_DIR/cloud-runner.lib"
source "$LIB_SCRIPT_DIR/bool.lib"
source "$CONF_FILE"

# Assign variables that rely on $CONF_FILE contents
LINODE_INPUT_DIR="$LINODE_SHARE/input"
LINODE_OUTPUT_DIR="$LINODE_SHARE/output"
#endregion


#region Parse input argumentsww

FILE_PATHS=()
ARGS_STRING="$*"

for arg in "$@"; do
    # if argument is a symlink resolve it to the actual file before adding to filepaths
    if [ -L "$arg" ]; then
        real_file=$(readlink -f "$arg")
        FILE_PATHS+=("$real_file")
        basename=$(basename "$arg")
        ARGS_STRING=$(echo "$ARGS_STRING" | sed "s|\"\{0,1\}$arg\"\{0,1\}|$LINODE_INPUT_DIR/$basename|g")
    # if argument is a valid file replace the filepath root with $LINODE_INPUT_DIR
    elif is_valid_file "$arg"; then
        FILE_PATHS+=("$arg")
        basename=$(basename "$arg")
        ARGS_STRING=$(echo "$ARGS_STRING" | sed "s|\"\{0,1\}$arg\"\{0,1\}|$LINODE_INPUT_DIR/$basename|g")
    #if argument isnt a file, but resolves to a directory somewhere down the line, consider it an output argument
    elif [[ "$arg" == *"/"* && "$arg" != *":"* ]]; then
        potential_path="$arg"
        pseudo_basename=""
        while [[ "$potential_path" == *"/"* ]]; do
            pseudo_basename="/$(basename "$potential_path")$pseudo_basename"
            potential_path=$(dirname "$potential_path")

            if is_valid_directory "$potential_path"; then
                ARGS_STRING=$(echo "$ARGS_STRING" | sed "s|$arg|$LINODE_OUTPUT_DIR$pseudo_basename|g")
                break
            fi
        done
    fi
done
#endregion


# region Upload stackscript to linode
echo "Uploading Cloud-Runner StackScript..."
lin stackscripts delete $(get_stackscript_id $STACKSCRIPT_LABEL) >/dev/null
create_linode_stackscript "$CLOUDRUNNER_STACKSCRIPT" "$STACKSCRIPT_LABEL" "$CLOUDRUNNER_DEFAULT_IMAGE" >/dev/null


# Build Stackscript arguments
# echo -e "\nBuilding StackScript Arguments..."
# PRIV_KEY_DATA=$(cat "$CLOUD_TO_HOME_KEY")
# PUB_KEY_DATA=$(cat "$CLOUD_TO_HOME_KEY.pub")
# STACKSCRIPT_DATA=$(jq -n \
#                   --arg privKey "$PRIV_KEY_DATA" \
#                   --arg pubKey "$PUB_KEY_DATA" \
#                   --arg sshPort "$SSH_PORT" \
#                   --arg sshIp "$PUB_IP" \
#                   --arg sshUser "$(whoami)" \
#                   '{PRIV_KEY: $privKey, PUB_KEY: $pubKey, SSH_PORT: $sshPort, SSH_IP: $sshIp, SSH_USER: $sshUser}')

#endregion


#region Deploy Linode

# make sure any previous log files are deleted
rm -f "$CLOUD_SHARE_LINK"/*.log

echo -e "\nCreating New Cloud-Runner Linode..."
lin linodes create \
    --root_pass "$(encode_password $CLOUDRUNNER_ROOT_PASS)" \
    --authorized_keys "$(cat $HOME_TO_CLOUD_KEY.pub)" \
    --label "$LINODE_LABEL" \
    --swap_size 8192 \
    --stackscript_id "$(get_stackscript_id $STACKSCRIPT_LABEL)"
    # --stackscript_data "$STACKSCRIPT_DATA" >/dev/null
sleep 1

# Get Linode's IP Address
echo -e "\nGetting Linode's IP Address..."
LINODE_IP=$(get_linode_ipv4 "$LINODE_LABEL")
#endregion


#region Confirm Successfull Deployment

# Wait for Linode's IP to respond
echo -e "\nWaiting for cloud-runner deployment to complete. Go grab a caffinated beverage."
sleep 120

# Loop until SSH connection is successful
encode_password "$CLOUDRUNNER_ROOT_PASS"
echo "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i $HOME_TO_CLOUD_KEY $SSH_USER@$LINODE_IP"
while true; do
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$HOME_TO_CLOUD_KEY" "$SSH_USER@$LINODE_IP" "echo 'SSH connection successful'" &>/dev/null; then
        echo "SSH connection to $LINODE_IP established successfully."
        break
    else
        echo "SSH connection to $LINODE_IP failed. Retrying..."
        sleep 5 
    fi
done


# TODO, Fix cloud directory so we have /opt/cloud-runner/cloud and cloud-runner/results, 
# sshf mount cloud, move contents to results. (will need to edit setup too)

# Mount LINODE_SHARE to CLOUD_SHARE_DIR and confirm successfull access to linode filesystem
# ssh $SSH_USER@$LINODE_IP "mkdir -p $LINODE_INPUT_DIR $LINODE_OUTPUT_DIR"
echo "sshfs -o allow_other,default_permissions -o IdentityFile=$HOME_TO_CLOUD_KEY $SSH_USER@$LINODE_IP:/$LINODE_SHARE $CLOUD_SHARE_DIR" 
sshfs -o StrictHostKeyChecking=no -o IdentityFile="$HOME_TO_CLOUD_KEY" "$SSH_USER@$LINODE_IP:/$LINODE_SHARE" "$CLOUD_SHARE_DIR"

echo -e "\n$LINODE_IP is now responding. Waiting for linode to complete stackscript..."
while true; do
    STACKSCRIPT_LOG=$(find "$CLOUD_SHARE_DIR" -name '*.log' -print -quit)
    if [ -n "$STACKSCRIPT_LOG" ]; then
        echo "Log file found in $STACKSCRIPT_LOG."
        cp "$STACKSCRIPT_LOG" "$HOME/Desktop/"
        break
    else
        sleep 2
    fi
done
echo -e "\n\n\t\t---[ Linode has been successfully Deployed! ]---"
#endregion

#-------------------------- Linode is now up --------------------------#





# Make sure LINODE_INPUT_DIR and LINODE_OUTPUT_DIR are initialized (they should be, but why not be redundant?)




# for file_path in "${FILE_PATHS[@]}"; do 
#     scp $file_path "$SSH_USER@$LINODE_IP:$LINODE_INPUT_DIR"


echo "$ARGS_STRING"
echo "Files to transfer:"
printf '%s\n' "${FILE_PATHS[@]}"


lin linodes delete $(get_linode_id $LINODE_LABEL)
lin linodes ls


