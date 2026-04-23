output "bucket_name" {
  value = module.s3.bucket_id
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "dms_replication_task_arn" {
  value = module.dms.replication_task_arn
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "state_machine_arn" {
  value = module.step_functions.state_machine_arn
}

output "redshift_cluster_identifier" {
  value = module.redshift.cluster_identifier
}

output "db_secret_arn" {
  value = module.rds.secret_arn
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}
