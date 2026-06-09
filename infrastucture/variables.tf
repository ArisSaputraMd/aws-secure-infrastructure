# =============================================
# Provider
# =============================================
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-southeast-3"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}


# =============================================
# Networking
# =============================================
variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


# =============================================
# Tags
# =============================================
variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "aws-secure-infra"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
