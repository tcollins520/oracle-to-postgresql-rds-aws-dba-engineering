# Outputs exposed by the reusable Secrets module.

output "oracle_source_secret_arn" {
  value = aws_secretsmanager_secret.oracle_source.arn
}
output "oracle_source_secret_name" {
  value = aws_secretsmanager_secret.oracle_source.name
}
output "postgres_target_secret_arn" {
  value = aws_secretsmanager_secret.postgres_target.arn
}
output "postgres_target_secret_name" {
  value = aws_secretsmanager_secret.postgres_target.name
}

output "oracle_schema_conversion_secret_arn" {
  value = aws_secretsmanager_secret.oracle_schema_conversion.arn
}
