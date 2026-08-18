# create security group for RDS
resource "aws_security_group" "db_sg" {
  name        = "${var.name}-db-sg"
  description = "Allow PostgreSQL from Vault"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from Vault"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = [var.vault_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-db-sg"
  }
}

# create a resource db subnet group for RDS instance
resource "aws_db_subnet_group" "db_subnet_group" {
  name = "${var.name}-db-subnet-group"

  subnet_ids = [
    var.private_subnet1_id,
    var.private_subnet2_id
  ]

  tags = {
    Name = "${var.name}-db-subnet-group"
  }
}

# create a resource random password for RDS instance
resource "random_password" "db_password" {
  length  = 20
  special = true
}

# create a resource RDS instance for vault database
resource "aws_db_instance" "vault_db" {

  identifier = "${var.name}-vault-db"

  engine         = "postgres"
  engine_version = "16"

  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  username = "vaultadmin"
  password = random_password.db_password.result

  port = 5432

  db_name = "vaultdb"

  multi_az = true

  publicly_accessible = false

  storage_encrypted = true

  kms_key_id = aws_kms_key.rds.arn

  backup_retention_period = 7

  skip_final_snapshot = false

  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]
  monitoring_interval          = 60
  performance_insights_enabled = true

  tags = {
    Name = "${var.name}-vault-db"
  }
}

# create a resource secrets manager secret to store RDS credentials
resource "aws_secretsmanager_secret" "vault_db" {
  name = "${var.name}-vault-db-secret"
}

# create a resource secrets manager secret version to store RDS credentials
resource "aws_secretsmanager_secret_version" "vault_db" {
  secret_id = aws_secretsmanager_secret.vault_db.id
  secret_string = jsonencode({
    username = aws_db_instance.vault_db.username
    password = random_password.db_password.result
    host     = aws_db_instance.vault_db.address
    port     = aws_db_instance.vault_db.port
    dbname   = aws_db_instance.vault_db.db_name
  })
}

resource "aws_kms_key" "rds" {
  description = "KMS key for Vault database"
}

# create a resource iam policy to allow vault instance to access RDS credentials in secrets manager
resource "aws_iam_policy" "vault_secret_policy" {

  name = "${var.name}-vault-secret-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_secretsmanager_secret.vault_db.arn
      }
    ]
  })
}

# create a resource iam role policy attachment to attach the policy to vault instance role
resource "aws_iam_role_policy_attachment" "vault_secret_policy_attachment" {

 role = var.vault_iam_role_name
  policy_arn = aws_iam_policy.vault_secret_policy.arn
}

# create a resource iam policy to allow vault instance to access RDS instance
resource "aws_iam_policy" "vault_rds_policy" {

  name = "${var.name}-vault-rds-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "rds:DescribeDBInstances"
        ]

        Resource = "*"
      }
    ]
  })
}

# create a resource iam role policy attachment to attach the policy to vault instance role
resource "aws_iam_role_policy_attachment" "vault_rds_policy_attachment" {

  role       = var.vault_iam_role_name
  policy_arn = aws_iam_policy.vault_rds_policy.arn
}

#