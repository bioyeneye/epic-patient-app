pipeline {
    agent any

    environment {
        REGISTRY = "harbor.buildplatform.net"
        PROJECT  = "library"
        IMAGE    = "epic-patient-app"
        TAG      = "${env.BUILD_NUMBER}" 
    }

    tools {
        nodejs "node-25.2.1"
    }

    stages {
        stage('🛑 Guard: Check Author') {
            steps {
                script {
                    def commitAuthorEmail = sh(script: "git log -1 --pretty=format:'%ae'", returnStdout: true).trim()
                    if (commitAuthorEmail == "jenkins@buildplatform.net") {
                        currentBuild.result = 'ABORTED'
                        error("Stopping Pipeline: Commit made by Jenkins Bot. Loop prevented.")
                    }
                }
            }
        }
        stage('Checkout') {
            steps {
                cleanWs() 
                script {
                    def scmVars = checkout scm

                    env.GIT_REMOTE_URL = scmVars.GIT_URL.replace("https://", "")

                    env.GIT_COMMIT_SHORT = scmVars.GIT_COMMIT.take(7)
                    env.GIT_BRANCH_NAME = scmVars.GIT_BRANCH.replaceAll('origin/', '')
                    echo "Building Branch: ${env.GIT_BRANCH_NAME} at Commit: ${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('Build Image') {
            steps {
                sh "docker build -t ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:${env.GIT_COMMIT_SHORT}-${env.TAG} ."
            }
        }

        stage('Push to Harbor') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'harbor-credentials', 
                                                        usernameVariable: 'HARBOR_USER', 
                                                        passwordVariable: 'HARBOR_PASS')]) {
                            sh """
                                echo "${HARBOR_PASS}" | docker login ${env.REGISTRY} -u "${HARBOR_USER}" --password-stdin
                                docker push ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:${env.GIT_COMMIT_SHORT}-${env.TAG}
                                docker tag ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:${env.GIT_COMMIT_SHORT}-${env.TAG} ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:latest
                                docker push ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:latest
                                docker logout ${env.REGISTRY}
                            """
                    }
                }
            }
        }

        stage('🚀 Update GitOps') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'github-app', 
                                                        usernameVariable: 'GIT_USER', 
                                                        passwordVariable: 'GIT_TOKEN')]) {
                        sh """
                            # 1. Debug: List files to find the correct path
                            echo "Current directory: \$(pwd)"
                            echo "Searching for deployment.yaml..."
                            ls -R | grep deployment.yaml || echo "File not found in search!"

                            # 2. Setup identity
                            git config user.email "jenkins@buildplatform.net"
                            git config user.name "Jenkins CI"

                            # 3. Update the image (Make sure this path is exactly what 'find' shows)
                            NEW_IMAGE="${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:${env.GIT_COMMIT_SHORT}-${env.TAG}"
                            
                            # Try to find the file dynamically if you aren't sure of the path:
                            TARGET_FILE=\$(find . -name "deployment.yaml" | head -n 1)
                            
                            if [ -f "\$TARGET_FILE" ]; then
                                sed -i "s|image: .*|image: \${NEW_IMAGE}|g" "\$TARGET_FILE"
                                git add "\$TARGET_FILE"
                                git commit -m "chore(gitops): update image to ${env.GIT_COMMIT_SHORT}-${env.TAG} [skip ci]"
                                git push https://${GIT_USER}:${GIT_TOKEN}@${env.GIT_REMOTE_URL} HEAD:${env.GIT_BRANCH_NAME}
                            else
                                echo "ERROR: deployment.yaml not found. Check your repo structure."
                                exit 1
                            fi
                        """
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                sh "docker rmi ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:${env.GIT_COMMIT_SHORT}-${env.TAG} || true"
            }
        }
    }

    post {
        always {
            deleteDir()
        }

        success {
            slackSend(
                channel: '#deployments', 
                color: 'good', 
                tokenCredentialId: 'slack-webhook-url',
                message: "✅ *Deployment Successful*\n*App:* ${env.IMAGE}\n*Tag:* ${env.GIT_COMMIT_SHORT}-${env.TAG}\n*URL:* https://k8s-epicpatient.buildplatform.net"
            )
        }
        failure {
            slackSend(
                channel: '#deployments', 
                color: 'danger', 
                tokenCredentialId: 'slack-webhook-url',
                message: "❌ *Build Failed*\n*Job:* ${env.JOB_NAME}\n*Build:* #${env.BUILD_NUMBER}"
            )
        }
    }
}