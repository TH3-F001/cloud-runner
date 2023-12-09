 #!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_SCRIPT_DIR="$SCRIPT_DIR/libraries"
CONF_DIR="$HOME/.config/linode"
TOKEN_FILE="$CONF_DIR/token"

source "$LIB_SCRIPT_DIR/basic-operations.lib"
source "$TOKEN_FILE"

export LINODE_CLI_TOKEN="$TOKEN"



# Clean up env tokens
export LINODE_CLI_TOKEN=""
