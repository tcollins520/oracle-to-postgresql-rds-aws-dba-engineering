# AWS providers, account context, Availability Zones, and shared local values.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Workload    = "OracleToPostgreSQL"
    }
  }
}

provider "awscc" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  artifacts_bucket_name = "orapgmig-${var.environment}-${local.account_id}-${var.aws_region}-artifacts"
}
