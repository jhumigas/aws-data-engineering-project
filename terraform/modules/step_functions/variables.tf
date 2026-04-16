variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "glue_job_names" {
  type = list(string)
  description = "List of Glue job names to reference in the state machine"
}
