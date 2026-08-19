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
                withCredentials([
                    string(
                        credentialsId: 'newrelic-api-key',
                        variable: 'TF_VAR_nr_key'
                    ),
                    string(
                        credentialsId: 'newrelic-account-id',
                        variable: 'TF_VAR_nr_acc_id'
                    )
                ]) {
                    sh '''
                        set -e

                        cat > terraform.tfvars <<EOF
name               = "seyi-project"
domain_name        = "seyi-prj2025.space"
nr_key             = "${TF_VAR_nr_key}"
nr_acc_id          = "${TF_VAR_nr_acc_id}"
pub_subnet1_cidr   = "10.0.1.0/24"
pub_subnet2_cidr   = "10.0.2.0/24"
priv_subnet1_cidr  = "10.0.3.0/24"
priv_subnet2_cidr  = "10.0.4.0/24"
pub_subnet1_az     = "eu-west-1a"
pub_subnet2_az     = "eu-west-1b"
priv_subnet1_az    = "eu-west-1a"
priv_subnet2_az    = "eu-west-1b"
vpc_cidr_block     = "10.0.0.0/16"
availability_zone  = "eu-west-1a"
bucket_name        = "seyi-project-ansible"
kms_key_id         = "alias/seyi-vault-kms-key"
vault_sg_cidr      = "10.0.2.0/24"
vault_vpc_cidr     = "10.0.0.0/16"
EOF

                        echo "===== Terraform Variables Prepared ====="

                        if [ "$DEPLOY_ACTION" = "DESTROY" ]; then
                            echo "===== Terraform Destroy Plan ====="

                            terraform plan \
                              -destroy \
                              -input=false \
                              -var-file=terraform.tfvars \
                              -out=tfplan.tfplan
                        else
                            echo "===== Terraform Deployment Plan ====="

                            terraform plan \
                              -input=false \
                              -var-file=terraform.tfvars \
                              -out=tfplan.tfplan
                        fi
                    '''
                }
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

                withCredentials([
                    string(
                        credentialsId: 'newrelic-api-key',
                        variable: 'TF_VAR_nr_key'
                    ),
                    string(
                        credentialsId: 'newrelic-account-id',
                        variable: 'TF_VAR_nr_acc_id'
                    )
                ]) {
                    sh '''
                        set -e

                        cat > terraform.tfvars <<EOF
name               = "seyi-project"
domain_name        = "seyi-prj2025.space"
nr_key             = "${TF_VAR_nr_key}"
nr_acc_id          = "${TF_VAR_nr_acc_id}"
pub_subnet1_cidr   = "10.0.1.0/24"
pub_subnet2_cidr   = "10.0.2.0/24"
priv_subnet1_cidr  = "10.0.3.0/24"
priv_subnet2_cidr  = "10.0.4.0/24"
pub_subnet1_az     = "eu-west-1a"
pub_subnet2_az     = "eu-west-1b"
priv_subnet1_az    = "eu-west-1a"
priv_subnet2_az    = "eu-west-1b"
vpc_cidr_block     = "10.0.0.0/16"
availability_zone  = "eu-west-1a"
bucket_name        = "seyi-project-ansible"
kms_key_id         = "alias/seyi-vault-kms-key"
vault_sg_cidr      = "10.0.2.0/24"
vault_vpc_cidr     = "10.0.0.0/16"
EOF

                        echo "===== Terraform Apply ====="

                        terraform apply \
                          -input=false \
                          tfplan.tfplan
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                rm -f tfplan.tfplan terraform.tfvars
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