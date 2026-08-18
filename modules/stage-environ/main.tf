# create a security group for the stage environment
resource "aws_security_group" "stage_sg" {
  name   = "${var.name}-stage-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.stage_alb_sg.id]
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

# create a security group for the stage ALB
resource "aws_security_group" "stage_alb_sg" {
  name   = "${var.name}-stage-alb-sg"
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

# create an IAM role for the stage environment
resource "aws_iam_role" "stage_role" {
  name = "${var.name}-stage-role"

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

# create an IAM role policy attachment to attach the AmazonSSMManagedInstanceCore policy to the stage role
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.stage_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create an IAM instance profile for the stage environment
resource "aws_iam_instance_profile" "stage_profile" {
  name = "${var.name}-stage-profile"
  role = aws_iam_role.stage_role.name
}

# data source to get the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    ]
  }
}

# 
resource "aws_launch_template" "stage" {

  name_prefix = "${var.name}-stage-"

  image_id = data.aws_ami.ubuntu.id

  instance_type = var.instance_type

  key_name = var.key_pair_name

  vpc_security_group_ids = [
    aws_security_group.stage_sg.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.stage_profile.name
  }

  user_data = base64encode(
  templatefile("${path.module}/dockerscript.sh", {
    nexus_ip  = var.nexus_ip
    nr_key    = var.nr_key
    nr_acc_id = var.nr_acc_id
  })
)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name}-stage"
    }
  }
}

# create an autoscaling group for the stage environment
resource "aws_autoscaling_group" "stage" {

  min_size = 1
  max_size = 3

  desired_capacity = 1

  vpc_zone_identifier = [
    var.private_subnet1_id,
    var.private_subnet2_id
  ]

  launch_template {
    id      = aws_launch_template.stage.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.stage_tg.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key = "Name"

    value = "${var.name}-stage"

    propagate_at_launch = true
  }
}

# create a load balancer for the stage environment
resource "aws_lb" "stage_alb" {

  name = "${var.name}-stage-alb"

  load_balancer_type = "application"

  security_groups = [
    aws_security_group.stage_alb_sg.id
  ]

  subnets = [
    var.public_subnet1_id,
    var.public_subnet2_id
  ]
}

# create a target group for the stage environment
resource "aws_lb_target_group" "stage_tg" {

  name = "${var.name}-stage-tg"

  port = 8080

  protocol = "HTTP"

  vpc_id = var.vpc_id

  health_check {
    path = "/"

    port = "traffic-port"
  }
}

# create an HTTPS listener for the stage environment
resource "aws_lb_listener" "https" {

  load_balancer_arn = aws_lb.stage_alb.arn

  port = 443

  protocol = "HTTPS"

  certificate_arn = var.acm_certificate_arn

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.stage_tg.arn
  }
}

# create a Route 53 record for the stage environment
resource "aws_route53_record" "stage" {

  zone_id = var.zone_id

  name = "app"

  type = "A"

  alias {
    name = aws_lb.stage_alb.dns_name

    zone_id = aws_lb.stage_alb.zone_id

    evaluate_target_health = true
  }
}

