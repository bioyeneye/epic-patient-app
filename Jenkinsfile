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
    }
}