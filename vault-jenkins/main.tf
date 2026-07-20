locals {
  name = "seyi-vault-jenkins"
}

# Create a resource vpc
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "${local.name}-vpc"
  }
}

# Create a resource public subnet1
resource "aws_subnet" "pub_subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.name}-subnet1"
  }
}

# Create a resource public subnet2
resource "aws_subnet" "pub_subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.name}-subnet2"
  }
}

# Create a resource internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.name}-igw"
  }
}

# Create a resource route table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.name}-rt"
  }
}

# Create a resource route       
resource "aws_route" "route" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Create a resource route table association for subnet1
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.pub_subnet1.id
  route_table_id = aws_route_table.rt.id
}

# Create a resource route table association for subnet2
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.pub_subnet2.id
  route_table_id = aws_route_table.rt.id
}

# Create a resource security group
resource "aws_security_group" "sg" {
  name        = "${local.name}-sg"
  description = "Allow SSH, jenkins and vault traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}

# Create a resource key pair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}

resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.key.public_key_openssh
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["amazon"]
}

# create a resource EC2 instance for jenkins server
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.pub_subnet1.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  key_name                    = aws_key_pair.public_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_jenkins_instance_profile.name
  root_block_device {
    volume_size = 20    # Size in GB
    volume_type = "gp3" # General Purpose SSD (recommended)
    encrypted   = true  # Enable encryption (best practice)
  }
  user_data = templatefile("./jenkins_userdata.sh", {

    region = var.region
  })
  metadata_options {
    http_tokens = "required"

  }

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# create a resource EC2 instance for vault server
resource "aws_instance" "vault_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.pub_subnet2.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  key_name                    = aws_key_pair.public_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vault_ssm_profile.name
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  # User data script to install Jenkins and required tools
  user_data = templatefile("./vault.sh", {
    region        = var.region,
    VAULT_VERSION = "1.18.3",
    key           = aws_kms_key.vault.id
  })
  metadata_options {
    http_tokens = "required"
  }
  tags = {
    Name = "${local.name}-vault-server"
  }
}

# create Jenkins iam role for jenkins server to assume ssm role
resource "aws_iam_role" "ssm_jenkins_role" {
  name = "${local.name}-ssm_jenkins_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attaching the AmazonSSMFullAccess policy to the role
resource "aws_iam_role_policy_attachment" "ssm_jenkins_role_attachment" {
  role       = aws_iam_role.ssm_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

#Attaching the instance profile to the role
resource "aws_iam_instance_profile" "ssm_jenkins_instance_profile" {
  name = "${local.name}-ssm_jenkins_instance_profile"
  role = aws_iam_role.ssm_jenkins_role.name
}

# Attach the administrative access policy to the role
resource "aws_iam_role_policy_attachment" "ssm_jenkins_admin_access_attachment" {
  role       = aws_iam_role.ssm_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create a resource ACM certificate with DNS validation for the domain name seyi-prj2025.space.
resource "aws_acm_certificate" "cert" {
  domain_name       = "seyi-prj2025.space"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "seyi_prj2025_zone" {
  name         = "seyi-prj2025.space."
  private_zone = false
}

# create  dns validation record for the ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.seyi_prj2025_zone.zone_id

  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# create a resource ACM certificate validation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.cert.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation :
    record.fqdn
  ]
}

# Create elastic Load Balancer for Jenkins
resource "aws_elb" "elb_jenkins" {
  name            = "${local.name}-elb-jenkins"
  security_groups = [aws_security_group.jenkins_elb_sg.id]
  subnets         = [aws_subnet.pub_subnet1.id, aws_subnet.pub_subnet2.id] # Use first available subnet

  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate.cert.arn
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8080"
  }
  instances                   = [aws_instance.jenkins_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create Route 53 record for jenkins server
resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.seyi_prj2025_zone.zone_id
  name    = "jenkins.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_jenkins.dns_name
    zone_id                = aws_elb.elb_jenkins.zone_id
    evaluate_target_health = true
  }
}

# create KMS key to manage vault unseal keys
resource "aws_kms_key" "vault" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  tags = {
    Name = "${local.name}-vault-kms-key"
  }
}

# create an alias for the KMS key
resource "aws_kms_alias" "vault" {
  name          = "alias/seyi-vault-kms-key"
  target_key_id = aws_kms_key.vault.key_id
}

# Security Group for ELB to allow HTTP traffic
resource "aws_security_group" "vault_sg" {
  name        = "${local.name}-vault-sg"
  description = "Allow HTTP traffic to server"
  vpc_id      = aws_vpc.vpc.id
  # Inbound: HTTP on port 80
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound: Allow all traffic (to EC2)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-vault-sg"
  }
}
#creating and attaching an IAM role with SSM permissions to the vault instance.
resource "aws_iam_role" "vault_ssm_role" {
  name = "${local.name}-ssm-vault-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
# create iam role policy to give permission to the kms role
resource "aws_iam_role_policy" "kms_policy" {
  name = "${local.name}-kms-policy1"
  role = aws_iam_role.vault_ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Effect   = "Allow"
        Resource = "${aws_kms_key.vault.arn}"
      }
    ]
  })
}
#Attach the AmazonSSMManagedInstanceCore policy
# — required for Session Manager and SSM Agent functionality.
resource "aws_iam_role_policy_attachment" "vault_ssm_attachment" {
  role       = aws_iam_role.vault_ssm_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# create instance profile for vault
resource "aws_iam_instance_profile" "vault_ssm_profile" {
  name = "${local.name}-ssm-vault-instance-profile"
  role = aws_iam_role.vault_ssm_role.id
}

# Create Security group for the jenkins elb
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Allow HTTPS"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-elb-sg"
  }
}

# Security Group for ELB to allow HTTP traffic
resource "aws_security_group" "vault_elb_sg" {
  name        = "${local.name}-vault-elb-sg"
  description = "Allow HTTP traffic to server"
  vpc_id      = aws_vpc.vpc.id
  # Inbound: HTTP on port 80
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound: Allow all traffic (to EC2)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-vault-elb-sg"
  }
}
# Create a new load balancer for vault
resource "aws_elb" "vault_elb" {
  name            = "${local.name}-vault-elb"
  subnets         = [aws_subnet.pub_subnet1.id, aws_subnet.pub_subnet2.id] # Use first available subnet
  security_groups = [aws_security_group.vault_elb_sg.id]
  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.cert.arn
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8200"
    interval            = 30
  }
  instances                   = [aws_instance.vault_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-vault-elb"
  }
}
# Create Route 53 record for vault server
resource "aws_route53_record" "vault_record" {
  zone_id = data.aws_route53_zone.seyi_prj2025_zone.zone_id
  name    = "vault.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.vault_elb.dns_name
    zone_id                = aws_elb.vault_elb.zone_id
    evaluate_target_health = true
  }
}