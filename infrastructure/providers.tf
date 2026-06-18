# Primary Provider for Main infrastructure
provider "aws" {
    region = var.aws_region
    profile = var.aws_profile
}

# Aliased Provider explicitly for Global Edge SSL Certificates (Virginia)
provider "aws" {
    alias = "us_east_1"
    region = "us-east-1"
    profile = var.aws_profile
}