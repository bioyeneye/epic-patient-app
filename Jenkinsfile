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

        stage('🏗️ Build Image') {
            steps {
                // Use double tagging: Build number for Jenkins, Hash for Git traceability
                sh "docker build -t ${REGISTRY}/${PROJECT}/${IMAGE}:${GIT_COMMIT_SHORT}-${TAG} ."
            }
        }

        stage('🔍 Image Audit') {
            steps {
                // Fail build if Trivy finds Critical/High vulnerabilities
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${REGISTRY}/${PROJECT}/${IMAGE}:${GIT_COMMIT_SHORT}-${TAG}"
            }
        }

        stage('📦 Push to Harbor') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'harbor-credentials', 
                                                        usernameVariable: 'HARBOR_USER', 
                                                        passwordVariable: 'HARBOR_PASS')]) {
                            sh """
                                echo "${HARBOR_PASS}" | docker login ${REGISTRY} -u "${HARBOR_USER}" --password-stdin
                                docker push ${REGISTRY}/${PROJECT}/${IMAGE}:${GIT_COMMIT_SHORT}-${TAG}
                                docker tag ${REGISTRY}/${PROJECT}/${IMAGE}:${GIT_COMMIT_SHORT}-${TAG} ${REGISTRY}/${PROJECT}/${IMAGE}:latest
                                docker push ${REGISTRY}/${PROJECT}/${IMAGE}:latest
                                docker logout ${REGISTRY}
                            """
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                sh "docker rmi ${DOCKER_IMAGE}:${env.BUILD_ID}"
            }
        }
    }

    post {
        always {
            echo 'Cleaning up workspace...'
            sh 'rm -rf venv' // Always clean up the local python environment
            sh "docker rmi ${REGISTRY}/${PROJECT}/${IMAGE}:${GIT_COMMIT_SHORT}-${TAG} || true"
            deleteDir()
        }
        success {
            echo 'Build and Deployment Successful!'
        }
        failure {
            echo 'Pipeline failed. Alerting Engineering team...'
        }
    }
}