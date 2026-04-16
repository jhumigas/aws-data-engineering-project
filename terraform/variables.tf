variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ca-central-1"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["ca-central-1a", "ca-central-1b"]
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-de-project"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}
