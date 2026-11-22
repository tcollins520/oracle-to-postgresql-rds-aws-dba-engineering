terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.98"
    }
  }

  backend "s3" {}
}