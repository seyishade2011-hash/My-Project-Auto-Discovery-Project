output "jenkins_server_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "vault_server_public_ip" {
  value = aws_instance.vault_server.public_ip
}