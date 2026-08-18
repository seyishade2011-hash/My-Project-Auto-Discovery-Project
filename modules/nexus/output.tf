output "nexus_instance_id" {
  value = aws_instance.nexus.id
}

output "nexus_public_ip" {
  value = aws_instance.nexus.public_ip
}

output "nexus_private_ip" {
  value = aws_instance.nexus.private_ip
}

output "nexus_alb_dns" {
  value = aws_lb.nexus_alb.dns_name
}

output "nexus_url" {
  value = "https://nexus.${var.domain_name}"
}