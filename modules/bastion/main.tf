# create security group for bastion host
resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion_sg"
  description = "allow only outbound traffic from bastion host"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-bastion_sg"
  }
}

# create iam role for ssm
resource "aws_iam_role" "bastion_ssm_role" {
  name = "${var.name}-bastion_ssm_role"
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

# create iam policy for ssm
resource "aws_iam_policy" "bastion_ssm_policy" {
  name = "${var.name}-bastion_ssm_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:SendCommand"
        ]
        Resource = "*"
      }
    ]
  })
}

# create iam instance profile for bastion host
resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${var.name}-bastion_instance_profile"
  role = aws_iam_role.bastion_ssm_role.name
}

# data source to get latest ubuntu ami
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# create a launch template for the bastion host
resource "aws_launch_template" "bastion_launch_template" {
  name_prefix            = "${var.name}-bastion-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.bastion_instance_profile.name
  }
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    private_key = var.private_key,
    nr_key      = var.nr_key,
    nr_acc_id   = var.nr_acc_id,
    region      = var.region
  }))
  lifecycle {
    create_before_destroy = true
  }
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name}-bastion"
    }
  }
}

# create an autoscaling group for the bastion host
resource "aws_autoscaling_group" "bastion_asg" {

  name = "${var.name}-bastion_asg"

  launch_template {
    id      = aws_launch_template.bastion_launch_template.id
    version = "$Latest"
  }

  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true

  vpc_zone_identifier = [var.public_subnet_id]

  tag {
    key                 = "Name"
    value               = "${var.name}-bastion"
    propagate_at_launch = true
  }
}

# create ASG policy to ensure that the bastion host is always running
resource "aws_autoscaling_policy" "bastion_asg_policy" {
  name                   = "${var.name}-bastion_asg_policy"
  autoscaling_group_name = aws_autoscaling_group.bastion_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}