#!/bin/bash
source "$(dirname "$0")/lib/utils.sh"
[ -f db_env.sh ] && source ./db_env.sh

# check_var "KEYVAULT_NAME"
# check_var "TARGET_SPN_DISPLAY_NAME"
# check_var "FINAL_OAUTH_SECRET"
# check_var "TARGET_APPLICATION_ID"

# Sanitize name
CLEAN_NAME=$(echo "$TARGET_SPN_DISPLAY_NAME" | tr ' ' '-')
ID_NAME="db-$CLEAN_NAME-id"
SECRET_NAME="db-$CLEAN_NAME-secret"

log_info "Target Key Vault: $KEYVAULT_NAME"
log_info "Target Secret: $SECRET_NAME"

# 1. Update App ID (For reference)
az keyvault secret set \
    --vault-name "$KEYVAULT_NAME" \
    --name "$ID_NAME" \
    --value "$TARGET_APPLICATION_ID" \
    --output none \
    --only-show-errors

# 2. Push New Secret & Capture Version ID
NEW_VERSION_ID=$(az keyvault secret set \
    --vault-name "$KEYVAULT_NAME" \
    --name "$SECRET_NAME" \
    --value "$FINAL_OAUTH_SECRET" \
    --query "id" -o tsv \
    --only-show-errors)

if [ -z "$NEW_VERSION_ID" ]; then
    log_error "Failed to set secret in Key Vault."
    exit 1
fi

log_info "New secret version created: ${NEW_VERSION_ID##*/}"

# 3. Disable Old Versions
log_info "Disabling older versions..."

OLD_VERSIONS=$(az keyvault secret list-versions \
    --vault-name "$KEYVAULT_NAME" \
    --name "$SECRET_NAME" \
    --query "[?attributes.enabled==\`true\` && id!='$NEW_VERSION_ID'].id" \
    -o tsv)

if [ -n "$OLD_VERSIONS" ]; then
    for version_id in $OLD_VERSIONS; do
        az keyvault secret set-attributes \
            --id "$version_id" \
            --enabled false \
            --output none \
            --only-show-errors
        log_info "Disabled version: ${version_id##*/}"
    done
else
    log_info "No old enabled versions found."
fi

log_info "Key Vault rotation complete."
