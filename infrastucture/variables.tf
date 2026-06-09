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

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
}
