#!/bin/bash
source "$(dirname "$0")/lib/utils.sh"

# Load State
if [ -f db_env.sh ]; then source ./db_env.sh; else log_error "db_env.sh missing"; exit 1; fi

check_var "DATABRICKS_HOST"
check_var "ACCOUNT_ID"
check_var "TARGET_SPN_DISPLAY_NAME"
check_var "DATABRICKS_TOKEN"

log_info "Fetching Internal ID for SPN: $TARGET_SPN_DISPLAY_NAME"

# 1. Fetch SPN Data
# Use URL encoding for safety
FILTER="displayName eq \"$TARGET_SPN_DISPLAY_NAME\""

RESPONSE=$(curl -s -G -X GET \
  -H "Authorization: Bearer $DATABRICKS_TOKEN" \
  --data-urlencode "filter=$FILTER" \
  "$DATABRICKS_HOST/api/2.0/accounts/$ACCOUNT_ID/scim/v2/ServicePrincipals")

# 2. Parse & Validate
INTERNAL_ID=$(echo "$RESPONSE" | jq -r '.Resources[0].id // empty')
APP_ID=$(echo "$RESPONSE" | jq -r '.Resources[0].applicationId // empty')

if [ -z "$INTERNAL_ID" ]; then
    log_error "SPN '$TARGET_SPN_DISPLAY_NAME' not found in Databricks Account."
    log_error "API Response: $RESPONSE"
    exit 1
fi

log_info "Found Internal ID: $INTERNAL_ID (App ID: $APP_ID)"

# 3. Check for Existing Secrets
SECRET_LIST=$(curl -s -X GET \
  -H "Authorization: Bearer $DATABRICKS_TOKEN" \
  "$DATABRICKS_HOST/api/2.0/accounts/$ACCOUNT_ID/servicePrincipals/$INTERNAL_ID/credentials/secrets")

SECRET_COUNT=$(echo "$SECRET_LIST" | jq '.secrets | length // 0')

log_info "Active secrets found: $SECRET_COUNT"

# 4. Export Data
echo "export DATABRICKS_INTERNAL_ID='$INTERNAL_ID'" >> db_env.sh
echo "export TARGET_APPLICATION_ID='$APP_ID'" >> db_env.sh
echo "export HAS_SECRETS='$SECRET_COUNT'" >> db_env.sh
