Automated Service Principal (SPN) Key Rotation Pipeline

Version: 2.0 (Industry Standard)

Orchestrator: Jenkins

Target Ecosystem: Azure Databricks, Azure Key Vault, Microsoft Fabric

1. Executive Summary

This project implements a robust, automated security pipeline designed to rotate Service Principal (SPN) credentials across the Azure Data Ecosystem.

Business Value:

Enhanced Security: Eliminates static, long-lived credentials by frequently rotating keys.

Zero Downtime: Synchronizes secret rotation across storage (Key Vault), generation (Databricks), and consumption (Microsoft Fabric) in a single atomic operation.

Compliance: Adheres to industry standards for logging, error handling, and auditability.

2. High-Level Architecture

The pipeline orchestrates a secure "handshake" between three critical Azure services.

graph LR
    A[Jenkins Pipeline] -->|1. Authenticate| B(Azure Entra ID)
    A -->|2. Generate New Secret| C(Azure Databricks)
    A -->|3. Archive Old & Store New| D(Azure Key Vault)
    A -->|4. Update Connection| E(Microsoft Fabric)
    
    style A fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#ccf,stroke:#333,stroke-width:2px
    style D fill:#cfc,stroke:#333,stroke-width:2px
    style E fill:#fcf,stroke:#333,stroke-width:2px


The Workflow Flow

Initiation: Jenkins triggers the job for a list of SPNs (or a single SPN).

Generation: The pipeline requests a new, high-entropy OAuth secret from Azure Databricks (valid for 1 year).

Storage: The new secret is immediately vaulted in Azure Key Vault, and previous versions are disabled to prevent rollback attacks.

Synchronization: The pipeline connects to Microsoft Fabric, identifies the specific connection using the SPN, and updates it with the new credentials live.

3. Technical Implementation

The solution is modular, built on a core library of shared functions for consistent error handling and logging.

Repository Structure

.
├── Jenkinsfile                  # Orchestration Logic (Groovy)
└── scripts/
    ├── lib/
    │   └── utils.sh             # Core Library (Logging, Validation, Strict Mode)
    ├── get_token.sh             # Authenticates Master SPN
    ├── fetch_internal_id.sh     # Maps Display Name -> Databricks Internal ID
    ├── delete_old_secrets.sh    # Cleanup logic (Limits management)
    ├── create_oauth_secret.sh   # Secret Generation API calls
    ├── store_keyvault.sh        # Key Vault Versioning & Storage
    └── update_fabric_connection.sh  # Fabric CLI Wrapper (Python)


Key Technical Features

Defensive Coding: All scripts run in strict mode (set -euo pipefail). If any command fails (e.g., a network timeout), the pipeline halts immediately to prevent data corruption.

Atomic Operations: Actions are verified before proceeding. For example, we confirm the secret is successfully stored in Key Vault before attempting to update Fabric.

Self-Healing Environment: The pipeline automatically builds its own Python virtual environment for the Fabric CLI and cleans up sensitive runtime files (db_env.sh) after execution.

4. Prerequisites & Requirements

To deploy this pipeline, the following infrastructure and access rights are required.

4.1 Jenkins Environment

Agent: Linux (Ubuntu/Debian recommended).

Binaries Required: bash, curl, jq, az (Azure CLI), python3 (with venv).

Jenkins Plugins: Credentials Binding, Timestamper.

4.2 Credentials (Jenkins Global Store)

The pipeline requires a "Master SPN" with permissions to manage other SPNs.

Credential ID

Description

azure-client-id

Client ID of the Master SPN.

azure-client-secret

Client Secret of the Master SPN.

azure-tenant-id

Azure Tenant ID.

azure-subscription-id

Azure Subscription ID.

keyvault-name

Name of the target Azure Key Vault.

databricks-account-id

Databricks Account Console ID.

4.3 Azure Permissions (RBAC)

The Master SPN must have:

Databricks: Service Principal Manager (to create secrets).

Key Vault: Key Vault Secrets Officer (to read/write/disable secrets).

Fabric: Admin or Contributor access to the target Workspace/Gateway.

5. Usage Guide

Running the Pipeline

Navigate to the Jenkins Job.

Click Build with Parameters.

SPN_LIST: Enter the Display Name of the SPN(s) you wish to rotate.

Single: marketing-etl-spn

Multiple: marketing-etl-spn, finance-report-spn

Click Build.

Verifying Success

Jenkins Logs: Look for the === Successfully Rotated [SPN Name] === message.

Azure Key Vault: Verify a new version of the secret exists and is "Enabled". Old versions should be "Disabled".

Fabric: Check the connection settings; the "Modified" timestamp should reflect the pipeline run.

6. Disaster Recovery & Troubleshooting

Issue

Potential Cause

Remediation

HTTP 403 / Permission Denied

Master SPN lacks RBAC roles.

specific permissions in Databricks Account Console and Key Vault IAM.

"Connection not found"

Naming mismatch in Fabric.

Ensure Fabric connection is named db-[SPN-NAME-WITH-DASHES].

Pipeline Failure

Transient Network/API error.

The pipeline is idempotent. Re-run the job for the failed SPN.

Documentation generated for automated compliance and architectural review.
