#!/bin/bash
source "$(dirname "$0")/lib/utils.sh"
[ -f db_env.sh ] && source ./db_env.sh

# check_var "DATABRICKS_INTERNAL_ID"
# check_var "ACCOUNT_ID"
# check_var "DATABRICKS_TOKEN"

log_info "Fetching secrets to purge for SPN ID: $DATABRICKS_INTERNAL_ID"

# 1. Get Secret List
LIST_RESPONSE=$(curl -s -X GET \
  -H "Authorization: Bearer $DATABRICKS_TOKEN" \
  "$DATABRICKS_HOST/api/2.0/accounts/$ACCOUNT_ID/servicePrincipals/$DATABRICKS_INTERNAL_ID/credentials/secrets")

# 2. Extract IDs safely into an array
mapfile -t SECRET_IDS < <(echo "$LIST_RESPONSE" | jq -r '.secrets[].id // empty')

if [ ${#SECRET_IDS[@]} -eq 0 ] || [ -z "${SECRET_IDS[0]}" ]; then
    log_info "No secrets found to delete."
    exit 0
fi

# 3. Delete Loop
for SID in "${SECRET_IDS[@]}"; do
    [ -z "$SID" ] && continue # Skip empty lines

    log_info "Deleting secret: $SID"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
      -H "Authorization: Bearer $DATABRICKS_TOKEN" \
      "$DATABRICKS_HOST/api/2.0/accounts/$ACCOUNT_ID/servicePrincipals/$DATABRICKS_INTERNAL_ID/credentials/secrets/$SID")

    if [ "$HTTP_CODE" -ne 204 ] && [ "$HTTP_CODE" -ne 200 ]; then
        log_warn "Failed to delete secret $SID. HTTP Code: $HTTP_CODE"
    fi
done

log_info "Old secrets purged."
