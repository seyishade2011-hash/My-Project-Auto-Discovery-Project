locals {
  name = "seyi-vault-jenkins"
}

# Create a resource vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
    tags = {
        Name = "${local.name}-vpc"
    }   
}

# Create a resource public subnet1
resource "aws_subnet" "pub_subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
    tags = {
        Name = "${local.name}-subnet1"
    }   
}

# Create a resource public subnet2
resource "aws_subnet" "pub_subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
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
    from_port  = 8080
    to_port    = 8080
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port  = 8200
    to_port    = 8200
    protocol   = "tcp"
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
  content = tls_private_key.key.private_key_pem
  filename = "${local.name}-key.pem"
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
  ami     = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub_subnet1.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name = aws_key_pair.key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# create a resource EC2 instance for vault server
resource "aws_instance" "vault_server" {
  ami   = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub_subnet2.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name = aws_key_pair.key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name}-vault-server"
  }
}

# attaching Jenkins iam role to jenkins server to assume ssm role
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

resource "aws_iam_role_policy_attachment" "ssm_jenkins_role_attachment" {
  role       = aws_iam_role.ssm_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "ssm_jenkins_instance_profile" {
  name = "${local.name}-ssm_jenkins_instance_profile"
  role = aws_iam_role.ssm_jenkins_role.name
}

# Attach the administrative access policy to the role
resource "aws_iam_role_policy_attachment" "ssm_jenkins_admin_access_attachment" {
  role       = aws_iam_role.ssm_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "example.com"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

