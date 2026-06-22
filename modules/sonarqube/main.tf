# create security groups for SonarQube instance and ALB
resource "aws_security_group" "sonarqube_sg" {
  name   = "${var.name}-sonarqube-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "SonarQube from ALB"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.sonarqube_alb_sg.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create security group for SonarQube ALB
resource "aws_security_group" "sonarqube_alb_sg" {
  name   = "${var.name}-sonarqube-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

# create an IAM role and instance profile for SonarQube instance
resource "aws_iam_role" "sonarqube_role" {
  name = "${var.name}-sonarqube-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

# attach AmazonSSMManagedInstanceCore policy to the role for SSM access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.sonarqube_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create an instance profile for the SonarQube instance
resource "aws_iam_instance_profile" "sonarqube_profile" {
  name = "${var.name}-sonarqube-profile"
  role = aws_iam_role.sonarqube_role.name
}

# data source to get the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# create an EC2 instance for SonarQube
resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true

  key_name = var.key_pair_name

  vpc_security_group_ids = [
    aws_security_group.sonarqube_sg.id
  ]

  iam_instance_profile = aws_iam_instance_profile.sonarqube_profile.name

  user_data = templatefile("${path.module}/userdata.sh", {
    db_host     = var.db_host
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
  })

  tags = {
    Name = "${var.name}-sonarqube"
  }
}

# create an ALB for SonarQube instance
resource "aws_lb" "sonarqube_alb" {
  name               = "${var.name}-sonarqube-alb"
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.sonarqube_alb_sg.id
  ]

  subnets = [
    var.public_subnet1_id,
    var.public_subnet2_id
  ]
}

# create a target group for SonarQube instance
resource "aws_lb_target_group" "sonarqube_tg" {
  name     = "${var.name}-sonarqube-tg"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# attach the SonarQube instance to the target group
resource "aws_lb_target_group_attachment" "sonarqube" {
  target_group_arn = aws_lb_target_group.sonarqube_tg.arn
  target_id        = aws_instance.sonarqube.id
  port             = 9000
}

# create an HTTPS listener for the ALB
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.sonarqube_alb.arn

  port     = 443
  protocol = "HTTPS"

  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonarqube_tg.arn
  }
}

# create an HTTP listener for the ALB to redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.sonarqube_alb.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# create a Route 53 record for SonarQube
resource "aws_route53_record" "sonarqube" {
  zone_id = var.zone_id

  name = "sonarqube"

  type = "A"

  alias {
    name                   = aws_lb.sonarqube_alb.dns_name
    zone_id                = aws_lb.sonarqube_alb.zone_id
    evaluate_target_health = true
  }
}

