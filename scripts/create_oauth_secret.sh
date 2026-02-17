#!/bin/bash
# Source the library (Error handling and logging are automatic now because of set -euo pipefail in utils)
source "$(dirname "$0")/lib/utils.sh"

# Load environment state
if [ -f db_env.sh ]; then
    source ./db_env.sh
else
    log_error "db_env.sh not found. Cannot proceed."
    exit 1
fi

# Validation
check_var "TARGET_SPN_DISPLAY_NAME"
check_var "DATABRICKS_INTERNAL_ID"
check_var "DATABRICKS_TOKEN"
check_var "ACCOUNT_ID"

log_info "Creating OAuth Secret for: $TARGET_SPN_DISPLAY_NAME ($DATABRICKS_INTERNAL_ID)"

# API Call with HTTP Code Capture (Robust method)
# We use a temporary file to store the body so we can separate body from status code
TEMP_BODY=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEMP_BODY" -X POST \
  -H "Authorization: Bearer $DATABRICKS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"lifetime_seconds\": 31536000, 
    \"comment\": \"Rotated via Jenkins for $TARGET_SPN_DISPLAY_NAME\"
  }" \
  "$DATABRICKS_HOST/api/2.0/accounts/$ACCOUNT_ID/servicePrincipals/$DATABRICKS_INTERNAL_ID/credentials/secrets")

RESPONSE_BODY=$(cat "$TEMP_BODY")
rm -f "$TEMP_BODY"

# Check if successful (200 OK or 201 Created)
if [[ "$HTTP_CODE" -ne 200 && "$HTTP_CODE" -ne 201 ]]; then
    check_api_success "200" "$HTTP_CODE" "$RESPONSE_BODY"
fi

# Extract Secret
OAUTH_SECRET_VALUE=$(echo "$RESPONSE_BODY" | jq -r '.secret // empty')

if [ -z "$OAUTH_SECRET_VALUE" ] || [ "$OAUTH_SECRET_VALUE" == "null" ]; then
    log_error "API returned success ($HTTP_CODE) but secret field was missing."
    exit 1
fi

log_info "Secret generated successfully."

# Append to state file
echo "export FINAL_OAUTH_SECRET='$OAUTH_SECRET_VALUE'" >> db_env.sh
