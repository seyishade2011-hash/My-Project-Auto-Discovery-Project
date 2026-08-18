# create security group for ansible server
resource "aws_security_group" "ansible_sg" {
  name        = "${var.name}-ansible-sg"
  description = "allow ssh traffic to ansible server"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow SSH traffic"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id] # allow ssh traffic from bastion host security group
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-ansible-sg"
  }
}

#data source to get latest red hat enterprise linux 8 ami
data "aws_ami" "red_hat_enterprise_linux_8" {
  most_recent = true

  owners = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-8*_HVM-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# create ansible server
resource "aws_instance" "ansible_server" {
  ami                         = data.aws_ami.red_hat_enterprise_linux_8.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.ansible_sg.id]
  user_data                   = local.ansible_userdata
  iam_instance_profile        = aws_iam_instance_profile.ansible_instance_profile.name
  associate_public_ip_address = true
  depends_on = [
    aws_s3_object.ansible_script_object,
    aws_s3_object.ansible_variable_file_object
  ]

  tags = {
    Name = "${var.name}-ansible-server"
  }
}

# create a resource to store ansible script in s3 bucket
resource "aws_s3_object" "ansible_script_object" {
  bucket = aws_s3_bucket.project_bucket.bucket
  key     = "ansible-script/ansible_script.sh"
  content = local.ansible_userdata
  acl     = "private"
}

# create a resource to store ansible variable file in s3 bucket
resource "aws_s3_object" "ansible_variable_file_object" {
  bucket = aws_s3_bucket.project_bucket.bucket
  key     = "ansible-script/ansible_variable_file.yml"
  content = <<-EOF
NEXUS_IP: ${var.nexus_ip}:8085
EOF
  acl     = "private"
}

# create iam role for ansible server
resource "aws_iam_role" "ansible_role" {
  name = "${var.name}-ansible-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# create iam policy for ansible server
resource "aws_iam_policy" "ansible_policy" {
  name = "${var.name}-ansible-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "arn:aws:s3:::${var.bucket_name}/ansible-script/*"
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones"
        ]

        Resource = "*"
      }
    ]
  })
}

# attach iam policy to iam role
resource "aws_iam_role_policy_attachment" "ansible_role_policy_attachment" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = aws_iam_policy.ansible_policy.arn
}

# create instance profile for ansible server
resource "aws_iam_instance_profile" "ansible_instance_profile" {
  name = "${var.name}-ansible-instance-profile"
  role = aws_iam_role.ansible_role.name
}

# attach the ssm managed instance core policy to the iam role
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create a null resource to trigger the creation of ansible server after the s3 objects have been created
resource "null_resource" "ansible_setup" {
  depends_on = [
    aws_s3_bucket.project_bucket
  ]

  provisioner "local-exec" {
    command = "aws s3 cp --recursive ${path.module}/script/ s3://${aws_s3_bucket.project_bucket.bucket}/ansible-script/"
  }
}

# create a s3 project bucket to store ansible script and variable file
resource "aws_s3_bucket" "project_bucket" {

  bucket = "${var.name}-ansible"

}