# Inputs for the reusable Iam module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "artifacts_bucket_arn" {
  type = string
}
variable "oracle_source_secret_arn" {
  type = string
}
variable "oracle_schema_conversion_secret_arn" {
  type = string
}
variable "postgres_secret_arn" {
  type = string
}
variable "postgres_master_secret_arn" {
  type = string
}
variable "manage_dms_vpc_role" {
  type = bool
}
variable "manage_dms_cloudwatch_logs_role" {
  type = bool
}
variable "tags" {
  type    = map(string)
  default = {}
}
