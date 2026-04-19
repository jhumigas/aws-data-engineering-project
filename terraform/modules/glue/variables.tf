variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "availability_zone" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "redshift_secret_arn" {
  type = string
}

variable "redshift_security_group_id" {
  type = string
}

variable "redshift_endpoint" {
  type = string
}
