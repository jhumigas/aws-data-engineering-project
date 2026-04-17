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
