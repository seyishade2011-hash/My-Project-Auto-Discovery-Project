pipeline {
    agent any

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
                withCredentials([
                    file(
                        credentialsId: 'terraform-tfvars',
                        variable: 'TFVARS_FILE'
                    )
                ]) {
                    sh '''
                        set -e

                        echo "===== Terraform Plan ====="

                        terraform plan \
                          -input=false \
                          -var-file="$TFVARS_FILE" \
                          -out=tfplan.tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                input message: 'Terraform plan succeeded. Proceed with infrastructure provisioning?', \
                      ok: 'Provision Infrastructure'

                sh '''
                    set -e

                    echo "===== Terraform Apply ====="

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