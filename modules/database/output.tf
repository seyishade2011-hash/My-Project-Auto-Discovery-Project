output "db_endpoint" {
  value = aws_db_instance.vault_db.endpoint
}

output "db_name" {
  value = aws_db_instance.vault_db.db_name
}   

output "db_secret_arn" {
  value = aws_secretsmanager_secret.vault_db.arn
}