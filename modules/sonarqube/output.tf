output "sonarqube_url" {
  value = "https://sonarqube.${var.domain_name}"
}

output "sonarqube_instance_id" {
  value = aws_instance.sonarqube.id
}

output "sonarqube_alb_dns" {
  value = aws_lb.sonarqube_alb.dns_name
}
