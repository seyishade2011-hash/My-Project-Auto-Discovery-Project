pipeline {
    agent any

    parameters {
        choice(
            name: 'DEPLOY_ACTION',
            choices: ['APPLY', 'DESTROY'],
            description: 'Choose whether to provision or destroy the infrastructure.'
        )
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
                        echo "===== Terraform Destroy Plan ====="

                        terraform plan \
                          -destroy \
                          -input=false \
                          -out=tfplan.tfplan
                    else
                        echo "===== Terraform Deployment Plan ====="

                        terraform plan \
                          -input=false \
                          -out=tfplan.tfplan
                    fi
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    if (params.DEPLOY_ACTION == 'DESTROY') {
                        input(
                            message: 'Terraform destroy plan succeeded. Proceed with infrastructure destruction?',
                            ok: 'Destroy Infrastructure'
                        )
                    } else {
                        input(
                            message: 'Terraform deployment plan succeeded. Proceed with infrastructure provisioning?',
                            ok: 'Provision Infrastructure'
                        )
                    }
                }

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
            echo ' Jenkins infrastructure operation SUCCESS'
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