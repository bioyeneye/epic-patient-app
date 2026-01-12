pipeline {
    agent any

    environment {
        REGISTRY = "harbor.buildplatform.net"
        PROJECT  = "library"
        IMAGE    = "epic-patient-app"
        TAG      = "${env.BUILD_NUMBER}" 
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
                }
            }
        }

        stage('Install & Test') {
            steps {
                echo "Skipping local install; Docker build will handle dependencies using Bun."
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
                            git config user.email "jenkins@buildplatform.net"
                            git config user.name "Jenkins CI"

                            NEW_IMAGE="${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:${env.GIT_COMMIT_SHORT}-${env.TAG}"
                            TARGET_FILE=\$(find . -name "deployment.yaml" | head -n 1)
                            
                            if [ -f "\$TARGET_FILE" ]; then
                                sed -i "s|image: .*|image: \${NEW_IMAGE}|g" "\$TARGET_FILE"
                                git add "\$TARGET_FILE"
                                # [skip ci] is the second layer of loop protection
                                git commit -m "chore(gitops): update image to ${env.GIT_COMMIT_SHORT}-${env.TAG} [skip ci]"
                                git push https://${GIT_USER}:${GIT_TOKEN}@${env.GIT_REMOTE_URL} HEAD:${env.GIT_BRANCH_NAME}
                            else
                                echo "ERROR: deployment.yaml not found."
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
                sh "docker rmi ${env.REGISTRY}/${env.PROJECT}/${env.IMAGE}:latest || true"
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