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

variable "rds_secret_arn" {
  type = string
}

variable "rds_security_group_id" {
  type = string
  description = "Security group of the RDS instance to allow ingress from Lambda"
}

variable "aws_region" {
  type        = string
  description = "AWS Region to use for Lambda environment variables"
}
