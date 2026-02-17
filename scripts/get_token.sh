#!/bin/bash
source "$(dirname "$0")/lib/utils.sh"

# Configuration


log_info "Starting Azure Authentication..."

# Validate inputs
check_var "AZURE_CLIENT_ID"
check_var "AZURE_CLIENT_SECRET"
check_var "AZURE_TENANT_ID"

# 1. Login with Service Principal
az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" > /dev/null 2>&1

log_info "Azure Login Successful."

# 2. Get Access Token
log_info "Fetching Databricks Access Token..."
DATABRICKS_TOKEN=$(az account get-access-token \
  --resource "$DATABRICKS_RESOURCE_ID" \
  --query accessToken -o tsv)

if [ -z "$DATABRICKS_TOKEN" ]; then
    log_error "Failed to retrieve access token. Result was empty."
    exit 1
fi

# 3. Export securely
echo "export DATABRICKS_TOKEN='$DATABRICKS_TOKEN'" > db_env.sh
log_info "Token acquired and saved to db_env.sh."
