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
# DNS
# =============================================
variable "domain_name" {
  description = "Root domain name for the project"
  type        = string
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
# Database
# =============================================
variable "db_name" {
  description = "Name of the Mattermost database"
  type        = string
  default     = "mattermost"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "mattermost"
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
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
