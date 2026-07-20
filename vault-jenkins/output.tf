output "jenkins_server_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "vault_server_public_ip" {
  value = aws_instance.vault_server.public_ip
}

output "acm_arn" {
  value = aws_acm_certificate.cert.arn
}

output "zone_id" {
  value = data.aws_route53_zone.seyi_prj2025_zone.zone_id
}

output "kms_key_arn" {
  value = aws_kms_key.vault.arn
}

output "vault_sg_id" {
  value = aws_security_group.vault_sg.id
}