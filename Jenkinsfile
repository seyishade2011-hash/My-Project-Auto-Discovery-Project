pipeline {
    agent any

        parameters {
        choice(
            name: 'DEPLOY_ACTION',
            choices: ['APPLY', 'DESTROY'],
            description: 'Choose whether to provision or destroy the infrastructure.'
        )
    }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
    }

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

                    if [ "$DEPLOY_ACTION" = "DESTROY" ]; then
                        terraform plan \
                          -destroy \
                          -input=false \
                          -out=tfplan.tfplan
                    else
                        terraform plan \
                          -input=false \
                          -out=tfplan.tfplan
                    fi
                '''
            }
        }

                stage('Terraform Apply') {
            steps {
                input message: "Proceed with ${DEPLOY_ACTION} infrastructure operation?", \
                      ok: "Proceed"

                sh '''
                    set -e

                    terraform apply \
                      -input=false \
                      tfplan.tfplan
                '''
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