# Primary Provider for Main infrastructure
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = var.managed_by
      Owner       = var.owner
      # DataClassification NOT in default_tags (force explicit per-resource declaration)
    }
  }
}

# Aliased Provider explicitly for Global Edge SSL Certificates (Virginia)
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = var.managed_by
      Owner       = var.owner
    }
  }
}
