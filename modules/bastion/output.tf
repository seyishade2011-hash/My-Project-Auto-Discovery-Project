output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "bastion_asg_name" {
  value = aws_autoscaling_group.bastion_asg.name
}

output "bastion_host_id" {
  value = aws_autoscaling_group.bastion_asg.id
}