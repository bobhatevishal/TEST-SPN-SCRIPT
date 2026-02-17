#!/bin/bash
source "$(dirname "$0")/lib/utils.sh"
[ -f db_env.sh ] && source ./db_env.sh

#check_var "FINAL_OAUTH_SECRET"
check_var "TARGET_SPN_DISPLAY_NAME"
check_var "TARGET_APPLICATION_ID"

# Gateway ID (Make configurable or use default)
GATEWAY_ID="${FABRIC_GATEWAY_ID:-34377033-6f6f-433a-9a66-3095e996f65c}"

log_info "Preparing Fabric CLI..."

# 1. Setup Python Env (Optimized)
if [ ! -d "fabricenv" ]; then
    log_info "Creating virtual environment..."
    python3 -m venv fabricenv
    source fabricenv/bin/activate
    pip install ms-fabric-cli==1.4.0 --quiet
else
    source fabricenv/bin/activate
fi

FAB="fabricenv/bin/fab"

# 2. Login
log_info "Logging into Fabric..."
$FAB auth login -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID" >/dev/null

# 3. Find Connection
CLEAN_NAME=$(echo "$TARGET_SPN_DISPLAY_NAME" | tr ' ' '-')
TARGET_CONNECTION="db-$CLEAN_NAME"

log_info "Searching for connection: $TARGET_CONNECTION"

RESPONSE=$($FAB api connections -A fabric)
CONNECTION_ID=$(echo "$RESPONSE" | jq -r --arg name "$TARGET_CONNECTION" \
  '.text.value[]? | select(.displayName==$name) | .id')

if [ -z "$CONNECTION_ID" ] || [ "$CONNECTION_ID" == "null" ]; then
    log_warn "Connection '$TARGET_CONNECTION' NOT FOUND in Fabric. Skipping update."
    exit 0
fi

log_info "Found Connection ID: $CONNECTION_ID. Updating..."

# 4. Update
cat <<EOF > update.json
{
  "connectivityType": "VirtualNetworkGateway",
  "displayName": "$TARGET_CONNECTION",
  "privacyLevel": "Private",
  "credentialDetails": {
    "singleSignOnType": "None",
    "credentials": {
      "credentialType": "Basic",
      "username": "$TARGET_APPLICATION_ID",
      "password": "$FINAL_OAUTH_SECRET"
    }
  }
}
EOF

$FAB api connections/$CONNECTION_ID -A fabric -X patch -i update.json >/dev/null

log_info "Fabric connection updated successfully."
rm -f update.json
