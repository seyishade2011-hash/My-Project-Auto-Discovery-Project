output "bastion_instance_id" {
  description = "Bastion Host EC2 Instance ID"
  value       = aws_instance.bastion_host.id
  
}