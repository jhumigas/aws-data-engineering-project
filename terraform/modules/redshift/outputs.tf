output "redshift_endpoint" {
  value = aws_redshift_cluster.main.endpoint
}

output "redshift_secret_arn" {
  value = aws_secretsmanager_secret.redshift_credentials.arn
}

output "redshift_security_group_id" {
  value = aws_security_group.redshift.id
}

output "database_name" {
  value = aws_redshift_cluster.main.database_name
}

output "cluster_identifier" {
  value = aws_redshift_cluster.main.cluster_identifier
}

output "role_arn" {
  value = aws_iam_role.redshift_role.arn
}
