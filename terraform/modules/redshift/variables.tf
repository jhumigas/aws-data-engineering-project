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

variable "vpc_cidr" {
  type = string
}

variable "bucket_arn" { # For IAM role to access S3
  type = string
}
