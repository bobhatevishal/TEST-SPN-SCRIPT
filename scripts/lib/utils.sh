#!/bin/bash

# 1. Strict Mode (Industry Standard)
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: If a command in a pipeline fails (e.g. curl | jq), the whole script fails.
set -euo pipefail

# 2. Structured Logging
log_info() {
    echo -e "[INFO]  $(date +'%Y-%m-%dT%H:%M:%S') - $1"
}

log_warn() {
    echo -e "[WARN]  $(date +'%Y-%m-%dT%H:%M:%S') - $1"
}

log_error() {
    echo -e "[ERROR] $(date +'%Y-%m-%dT%H:%M:%S') - $1" >&2
}

# 3. Variable Validation Helper
# Usage: check_var "VARIABLE_NAME"
check_var() {
    local var_name="$1"
    if [ -z "${!var_name:-}" ]; then
        log_error "Required environment variable '$var_name' is missing or empty."
        exit 1
    fi
}

# 4. API Error Handler
# Usage: check_http_response "200" "404" "$response_code" "$response_body"
check_api_success() {
    local expected="$1"
    local actual_code="$2"
    local response_body="$3"

    if [ "$actual_code" != "$expected" ]; then
        log_error "API Request Failed. Expected $expected, got $actual_code"
        log_error "Response: $response_body"
        exit 1
    fi
}
