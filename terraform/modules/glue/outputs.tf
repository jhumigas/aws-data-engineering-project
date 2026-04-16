output "job_names" {
  value = [for job in aws_glue_job.job : job.name]
}

output "crawler_names" {
  value = [aws_glue_crawler.bronze.name]
}
