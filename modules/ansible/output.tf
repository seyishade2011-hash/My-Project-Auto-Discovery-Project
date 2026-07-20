output "ansible_instance_id" {
  value = aws_instance.ansible_server.id
}

output "ansible_public_ip" {
  value = aws_instance.ansible_server.public_ip
}

output "ansible_private_ip" {
  value = aws_instance.ansible_server.private_ip
}

output "ansible_security_group_id" {
  value = aws_security_group.ansible_sg.id
}

output "ansible_role_arn" {
  value = aws_iam_role.ansible_role.arn
}

output "public_ip" {
  value = aws_instance.ansible_server.public_ip
}