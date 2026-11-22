# Inputs for the reusable Postgresql Instance module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "database_name" {
  type = string
}
variable "master_username" {
  type = string
}
variable "engine_version" {
  type = string
}
variable "instance_class" {
  type = string
}
variable "allocated_storage" {
  type = number
}
variable "max_allocated_storage" {
  type = number
}
variable "multi_az" {
  type = bool
}
variable "backup_retention_days" {
  type = number
}
variable "deletion_protection" {
  type = bool
}
variable "subnet_group_name" {
  type = string
}
variable "security_group_id" {
  type = string
}
variable "parameter_group_name" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
