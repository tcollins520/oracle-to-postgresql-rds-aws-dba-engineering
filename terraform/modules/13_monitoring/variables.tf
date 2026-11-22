# Inputs for the monitoring module.

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "postgres_instance_id" {
  type = string
}

variable "dms_replication_instance_id" {
  type = string
}

variable "tunnel_gateway_instance_id" {
  type = string
}

variable "notification_email" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}