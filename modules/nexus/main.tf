# create a resource security group for nexus instance
resource "aws_security_group" "nexus_sg" {
  name        = "${var.name}-nexus-sg"
  description = "Allow Nexus and SSH access"
  vpc_id      = var.vpc_id

  ingress {
  description     = "SSH from Bastion"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [var.bastion_sg_id]
}
  ingress {
  description     = "Nexus UI from ALB"
  from_port       = 8081
  to_port         = 8081
  protocol        = "tcp"
  security_groups = [aws_security_group.nexus_alb_sg.id]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-nexus-sg"
  }
}

#create a resource ami for nexus instance
data "aws_ami" "rhel" {
  most_recent = true

  owners = ["309956199498"] # Red Hat

  filter {
  name   = "name"
  values = ["RHEL-8*_HVM-*"]
}

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# create a resource nexus instance
resource "aws_instance" "nexus" {
  ami                         = data.aws_ami.rhel.id
  instance_type              = var.instance_type
  subnet_id                  = var.public_subnet1_id
  vpc_security_group_ids     = [aws_security_group.nexus_sg.id]
  key_name                   = var.key_pair_name
  iam_instance_profile       = aws_iam_instance_profile.nexus_profile.name
  associate_public_ip_address = true
  depends_on = [
    aws_instance_profile.nexus_profile,
    aws_iam_role_policy_attachment.ssm
    ]

  user_data = file("${path.module}/userdata.sh")

  tags = {
    Name = "${var.name}-nexus"
  }
}

# create a resource iam role for nexus instance
resource "aws_iam_role" "nexus_role" {
  name = "${var.name}-nexus-role"

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

# create a resource iam role policy attachment for nexus instance
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nexus_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create a resource iam instance profile for nexus instance
resource "aws_iam_instance_profile" "nexus_profile" {
  name = "${var.name}-nexus-profile"
  role = aws_iam_role.nexus_role.name
}

# create a resource application load balancer for nexus instance
resource "aws_lb" "nexus_alb" {
  name               = "${var.name}-nexus-alb"
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.nexus_alb_sg.id
  ]
  enable_deletion_protection = false

  subnets = [
    var.public_subnet1_id,
    var.public_subnet2_id
  ]
}

# create a resource security group for nexus application load balancer  
resource "aws_security_group" "nexus_alb_sg" {
  name        = "${var.name}-nexus-alb-sg"
  description = "Allow HTTP access to Nexus ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.name}-nexus-alb-sg"
    }
}

# create a resource target group for nexus instance
resource "aws_lb_target_group" "nexus_tg" {
  name     = "${var.name}-nexus-tg"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
  enabled             = true
  path                = "/"
  port                = "traffic-port"
  interval            = 30
  timeout             = 10
  healthy_threshold   = 3
  unhealthy_threshold = 5
}
}

# create a resource target group attachment for nexus instance
resource "aws_lb_target_group_attachment" "nexus" {
  target_group_arn = aws_lb_target_group.nexus_tg.arn
  target_id        = aws_instance.nexus.id
  port             = 8081
}

# create a resource listener for nexus application load balancer
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.nexus_alb.arn

  port     = 443
  protocol = "HTTPS"

  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nexus_tg.arn
  }
}

#
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nexus_alb.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# create a resource route53 record for nexus application load balancer
resource "aws_route53_record" "nexus" {
  zone_id = var.zone_id
  name    = "nexus"
  type    = "A"

  alias {
    name                   = aws_lb.nexus_alb.dns_name
    zone_id                = aws_lb.nexus_alb.zone_id
    evaluate_target_health = true
  }
}