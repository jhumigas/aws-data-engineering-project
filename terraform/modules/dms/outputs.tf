output "replication_task_arn" {
  value = aws_dms_replication_task.main.replication_task_arn
}

output "s3_role_arn" {
  value = aws_iam_role.dms_s3_role.arn
}
