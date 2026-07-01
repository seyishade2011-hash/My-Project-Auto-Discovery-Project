output "bastion_instance_id" {
  description = "Bastion Host EC2 Instance ID"
  value       = aws_instance.bastion_host.id
  
}

output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "bastion_asg_id" {
  value = aws_autoscaling_group.bastion_asg.id
}

output "bastion_host_id" {
  value = aws_autoscaling_group.bastion_asg.id
}