# Inputs for the reusable Dms module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "dms_security_group_id" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "oracle_source_secret_arn" {
  type = string
}
variable "postgres_secret_arn" {
  type = string
}
variable "endpoint_secrets_role_arn" {
  type = string
}
variable "secrets_manager_endpoint_dns_name" {
  type = string
}
variable "tunnel_listen_port" {
  type = number
}
variable "oracle_service_name" {
  type = string
}
variable "postgres_database_name" {
  type = string
}
variable "source_schemas" {
  type = list(string)
}
variable "replication_instance_class" {
  type = string
}
variable "replication_multi_az" {
  type = bool
}
variable "allocated_storage" {
  type = number
}
variable "create_endpoints" {
  type = bool
}
variable "create_task" {
  type = bool
}
variable "tags" {
  type    = map(string)
  default = {}
}
