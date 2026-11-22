# Inputs for the reusable Schema Conversion module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "oracle_server_name" {
  type = string
}
variable "oracle_service_name" {
  type = string
}
variable "oracle_port" {
  type = number
}
variable "oracle_secret_arn" {
  type = string
}
variable "postgres_server_name" {
  type = string
}
variable "postgres_database_name" {
  type = string
}
variable "postgres_secret_arn" {
  type = string
}
variable "secrets_access_role_arn" {
  type = string
}
variable "schema_conversion_s3_role_arn" {
  type = string
}
variable "schema_conversion_bucket_name" {
  type = string
}
variable "schema_conversion_subnet_group_id" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "dms_security_group_id" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
