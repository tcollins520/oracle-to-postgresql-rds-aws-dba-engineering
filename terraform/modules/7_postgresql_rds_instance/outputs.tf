# Outputs exposed by the reusable Postgresql Instance module.

output "instance_identifier" {
  value = aws_db_instance.postgres.identifier
}
output "instance_arn" {
  value = aws_db_instance.postgres.arn
}
output "address" {
  value = aws_db_instance.postgres.address
}
output "port" {
  value = aws_db_instance.postgres.port
}
output "master_user_secret_arn" {
  value       = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
  description = "RDS-managed master credential secret ARN."
  sensitive   = true
}
