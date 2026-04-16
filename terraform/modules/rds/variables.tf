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

variable "allowed_security_group_ids" {
  type = list(string)
  default = []
}

variable "db_password" { # We should probably generate this or pass it in, but for Terraform we can use a random_password resource
  type        = string 
  default     = null # If null, will be generated
}
