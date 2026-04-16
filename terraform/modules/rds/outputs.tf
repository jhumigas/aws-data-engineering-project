output "db_instance_address" {
  value = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_instance_username" {
  value = aws_db_instance.main.username
}

output "db_instance_password" {
  value     = aws_db_instance.main.password
  sensitive = true
}

output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
