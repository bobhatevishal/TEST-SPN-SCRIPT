pipeline {
    agent any

    options {
        timestamps()                  // Add time to console logs
        timeout(time: 1, unit: 'HOURS') // Prevent hanging jobs
        disableConcurrentBuilds()     // Prevent race conditions on shared resources
        ansiColor('xterm')            // Pretty colors in logs
    }

    parameters {
        string(name: 'SPN_LIST', defaultValue: 'automation-spn', description: 'SPN Name, comma-separated list, or "ALL"')
    }

    environment {
        // Global Config
        DATABRICKS_HOST       = 'https://accounts.azuredatabricks.net'
        
        // Credentials (Best Practice: Use 'credentials' binding for masking)
        KEYVAULT_NAME         = credentials('keyvault-name')
        ACCOUNT_ID            = credentials('databricks-account-id')
        AZURE_CRED            = credentials('azure-service-principal') // Bind username/pass to env vars automatically
        
        // Fabric
        FABRIC_WORKSPACE_ID   = 'yo782d76e6-7830-4038-8613-894916a67b22'
    }

    stages {
        stage('Setup Workspace') {
            steps {
                script {
                    // Make scripts executable
                    sh 'chmod +x scripts/*.sh scripts/lib/*.sh'
                    
                    // Generate initial token
                    // Pass credentials explicitly to avoid leaking them in shell history
                    withEnv(["AZURE_CLIENT_ID=${AZURE_CRED_USR}", "AZURE_CLIENT_SECRET=${AZURE_CRED_PSW}"]) {
                        sh './scripts/get_token.sh'
                    }
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
                echo "Cleaning up sensitive runtime files..."
                sh 'rm -f db_env.sh update.json'
            }
            cleanWs() // Standard Jenkins cleanup
        }
        failure {
            echo "Pipeline failed. Check logs for details."
            // Add email notification here if needed
        }
    }
}
