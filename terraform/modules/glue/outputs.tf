output "job_names" {
  value = [for job in aws_glue_job.job : job.name]
}

output "job_names_map" {
  value = { for k, v in aws_glue_job.job : k => v.name }
}

output "crawler_names" {
  value = [for crawler in aws_glue_crawler.tables : crawler.name]
}

output "role_arn" {
  value = aws_iam_role.glue_role.arn
}
