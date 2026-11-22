# Inputs for the reusable Security module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "oracle_source_cidr" {
  type = string
}
variable "tunnel_listen_port" {
  type = number
}
variable "postgres_port" {
  type = number
}
variable "tags" {
  type    = map(string)
  default = {}
}
