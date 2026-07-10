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

variable "app_subdomain" {
  default = "mattermost"
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
# ECS
# =============================================
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "mattermost-cluster"
}

# =============================================
# S3
# =============================================
# app bucket
variable "mattermost_files_force_destroy" {
  description = "Delete S3 bucket when Terraform destroy"
  type        = bool
  default     = false
}

# logs bucket
variable "logs_bucket_force_destroy" {
  description = <<-EOT
      Whether to force-delete all objects in the security logs bucket on destroy.
      Must be false in prod — COMPLIANCE object lock will block force-destroy anyway,
      but keeping this false makes the intent explicit and prevents accidents.
    EOT
  type        = bool
  default     = false
}

variable "logs_bucket_object_lock" {
  description = "dev env will be set to false, and true for prod env"
  type        = bool
  default     = false
}

variable "bucket_compliance_days" {
  type        = number
  description = "Compliance retention for logs bucket"
  default     = 365
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

# =============================================
# Alerts recipients
# =============================================
variable "security_email" {
  description = "Email address for all security alerts"
  type = string
}

variable "root_owner_email" {
  description = "Email address for root account security related"
  type = string
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

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "arissaputra"

  validation {
    condition = contains(
      [
        "arissaputra",
        "security-team",
        "devops-team"
      ],
      var.owner
    )
    error_message = "Allowed values: arissaputra, security-team, devops-team."
  }
}

variable "managed_by" {
  description = "Entity responsible for managing the resources"
  type        = string
  default     = "Terraform"

  validation {
    condition = contains(
      [
        "Terraform",
        "CloudFormation",
        "Manual"
      ],
      var.managed_by
    )
    error_message = "Allowed values: Terraform, CloudFormation, Manual."
  }
}


variable "data_classification" {
  description = "Classification level of the data handled by the resources"
  type        = string
  default     = "internal"

  validation {
    condition = contains(
      [
        "public",
        "internal",
        "confidential",
        "restricted"
      ],
      var.data_classification
    )

    error_message = "Allowed values: public, internal, confidential, restricted."
  }
}
