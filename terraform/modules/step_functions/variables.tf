variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "glue_job_names" {
  type        = map(string)
  description = "Map of Glue job names"
}

variable "glue_crawler_names" {
  type        = list(string)
  description = "List of Glue crawler names"
}

variable "redshift_cluster_identifier" {
  type = string
}

variable "redshift_database" {
  type = string
}

variable "redshift_db_user" {
  type        = string
  description = "Database user the Redshift Data API runs the merge procedures as"
  default     = "adminuser"
}

variable "execution_timeout_seconds" {
  type        = number
  description = "Upper bound for one pipeline execution, so a stuck poll loop cannot run forever"
  default     = 7200
}
