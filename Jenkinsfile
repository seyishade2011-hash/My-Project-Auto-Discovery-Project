pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'eu-west-1'
        AWS_REGION         = 'eu-west-1'
        TF_IN_AUTOMATION   = 'true'
    }

    stages {

        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                    set -e

                    echo "===== Git ====="
                    git --version

                    echo "===== Terraform ====="
                    terraform version

                    echo "===== AWS CLI ====="
                    aws --version

                    echo "===== AWS Identity ====="
                    aws sts get-caller-identity

                    echo "===== Working Directory ====="
                    pwd
                    ls -la
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                sh '''
                    set -e

                    terraform init \
                      -input=false \
                      -reconfigure
                '''
            }
        }

        stage('Terraform Validate') {
            steps {
                sh '''
                    set -e

                    terraform fmt -check -recursive
                    terraform validate
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                sh '''
                    set -e

                    terraform plan \
                      -input=false \
                      -out=tfplan.tfplan
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                sh '''
                    set -e

                    terraform apply \
                      -input=false \
                      tfplan.tfplan
                '''
            }
        }
    }

    post {
        always {
            sh '''
                rm -f tfplan.tfplan
            '''
        }

        success {
            echo '=========================================='
            echo ' Jenkins infrastructure deployment SUCCESS'
            echo '=========================================='
        }

        failure {
            echo '=========================================='
            echo ' Jenkins pipeline FAILED'
            echo 'Check the failed stage above.'
            echo '=========================================='
        }
    }
}