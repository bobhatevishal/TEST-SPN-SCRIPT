pipeline {
    agent any

    options {
        timestamps()                  // Add time to console logs
        timeout(time: 1, unit: 'HOURS') // Prevent hanging jobs
        disableConcurrentBuilds()     // Prevent race conditions on shared resources
        // ansiColor('xterm')         // Commented out to prevent "Invalid option" error
    }

    parameters {
        string(name: 'SPN_LIST', defaultValue: 'automation-spn', description: 'SPN Name, comma-separated list, or "ALL"')
    }

    environment {
        // --- Azure & Databricks Config ---
        DATABRICKS_HOST       = 'https://accounts.azuredatabricks.net'
        KEYVAULT_NAME         = credentials('keyvault-name')
        ACCOUNT_ID            = credentials('databricks-account-id')

        // --- Service Principal (Restored to your original variables) ---
        // These will be automatically available to all shell scripts as env vars
        AZURE_CLIENT_ID       = credentials('azure-client-id')
        AZURE_CLIENT_SECRET   = credentials('azure-client-secret')
        AZURE_TENANT_ID       = credentials('azure-tenant-id')
        AZURE_SUBSCRIPTION_ID = credentials('azure-subscription-id')

        // --- Fabric Configuration ---
        FABRIC_WORKSPACE_ID   = 'yo782d76e6-7830-4038-8613-894916a67b22'
    }

    stages {
        stage('Setup Workspace') {
            steps {
                script {
                    // Make scripts executable
                    sh 'chmod +x scripts/*.sh scripts/lib/*.sh'
                    
                    // Generate initial token
                    // No need for 'withEnv' here anymore because AZURE_CLIENT_ID 
                    // and AZURE_CLIENT_SECRET are already defined globally above.
                    sh './scripts/get_token.sh'
                }
            }
        }

        stage('Rotate Secrets') {
            steps {
                script {
                    def spns = []
                    if (params.SPN_LIST.toUpperCase() == 'ALL') {
                        error "Processing 'ALL' is not yet implemented safely. Please specify SPN names."
                    } else {
                        spns = params.SPN_LIST.split(',').collect { it.trim() }
                    }

                    boolean overallSuccess = true
                    def failedSpns = []

                    spns.each { spn ->
                        // Group logs by SPN for readability
                        stage("Rotation: ${spn}") {
                            try {
                                echo "=== Starting Rotation for ${spn} ==="
                                
                                // Isolate env vars for this iteration
                                withEnv(["TARGET_SPN_DISPLAY_NAME=${spn}"]) {
                                    
                                    // 1. Fetch Metadata
                                    sh './scripts/fetch_internal_id.sh'

                                    // 2. Check & Delete Old Secrets
                                    def hasSecrets = sh(script: ". ./db_env.sh && echo \$HAS_SECRETS", returnStdout: true).trim()
                                    
                                    if (hasSecrets.isInteger() && hasSecrets.toInteger() > 0) {
                                        echo "Found ${hasSecrets} existing secrets. Purging..."
                                        sh './scripts/delete_old_secrets.sh'
                                    } else {
                                        echo "No existing secrets found."
                                    }

                                    // 3. Create New Secret
                                    sh './scripts/create_oauth_secret.sh'

                                    // 4. Update Key Vault
                                    sh './scripts/store_keyvault.sh'

                                    // 5. Update Fabric
                                    sh './scripts/update_fabric_connection_if_exists.sh'
                                }
                                echo "=== Successfully Rotated ${spn} ==="

                            } catch (Exception e) {
                                echo "!!! FAILED processing ${spn} !!!"
                                echo "Error: ${e.getMessage()}"
                                overallSuccess = false
                                failedSpns.add(spn)
                                currentBuild.result = 'UNSTABLE' // Mark unstable but continue loop
                            }
                        }
                    }

                    if (!overallSuccess) {
                        error "Rotation failed for the following SPNs: ${failedSpns.join(', ')}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Safety check to prevent "MissingContextVariableException" if the node dies early
                if (currentBuild.result != 'NOT_BUILT') {
                    try {
                        echo "Cleaning up sensitive runtime files..."
                        sh 'rm -f db_env.sh update.json'
                        cleanWs() 
                    } catch (Exception e) {
                        echo "Cleanup warning: ${e.getMessage()}"
                    }
                }
            }
        }
        failure {
            echo "Pipeline failed. Check logs for details."
        }
    }
}
