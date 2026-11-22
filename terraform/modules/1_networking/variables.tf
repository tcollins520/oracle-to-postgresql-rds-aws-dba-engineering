# Inputs for the reusable Networking module.

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "availability_zones" {
  type = map(string)
}
variable "public_subnet_cidrs" {
  type = map(string)
}
variable "private_subnet_cidrs" {
  type = map(string)
}
variable "enable_nat_gateway" {
  type = bool
}
variable "single_nat_gateway" {
  type = bool
}
variable "tags" {
  type    = map(string)
  default = {}
}
