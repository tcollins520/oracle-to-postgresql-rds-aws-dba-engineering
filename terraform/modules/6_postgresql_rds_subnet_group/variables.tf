# Inputs for the reusable Postgresql Subnet Group module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "tags" {
  type    = map(string)
  default = {}
}
