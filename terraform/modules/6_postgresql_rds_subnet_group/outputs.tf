# Outputs exposed by the reusable Postgresql Subnet Group module.

output "subnet_group_name" {
  value = aws_db_subnet_group.postgres.name
}
output "subnet_group_arn" {
  value = aws_db_subnet_group.postgres.arn
}
