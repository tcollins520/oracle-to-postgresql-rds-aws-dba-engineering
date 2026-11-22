# Inputs for the Terraform state backend.

variable "aws_region" {
  description = "Region for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for this project's Terraform state."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Use a globally unique lowercase S3 bucket name (3-63 characters)."
  }
}
