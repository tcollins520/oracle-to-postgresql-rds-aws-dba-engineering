# Inputs for the reusable Ec2 Tunnel Gateway module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "private_ip" {
  type = string
}
variable "security_group_id" {
  type = string
}
variable "instance_profile_name" {
  type = string
}
variable "public_key" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "tunnel_listen_port" {
  type = number
}
variable "kms_key_arn" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
