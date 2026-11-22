# Outputs exposed by the reusable Postgresql Configuration module.

output "parameter_group_name" {
  value = aws_db_parameter_group.postgres.name
}
output "parameter_group_arn" {
  value = aws_db_parameter_group.postgres.arn
}
