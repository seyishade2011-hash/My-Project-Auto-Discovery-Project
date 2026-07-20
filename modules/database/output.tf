output "db_endpoint" {
  value = aws_db_instance.vault_db.address
}

output "db_name" {
  value = aws_db_instance.vault_db.db_name
}

output "db_username" {
  value = aws_db_instance.vault_db.username
}

output "db_password" {
  value = random_password.db_password.result
}

output "db_port" {
  value = aws_db_instance.vault_db.port
}