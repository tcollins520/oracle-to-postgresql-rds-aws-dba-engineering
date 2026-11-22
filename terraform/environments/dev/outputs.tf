# Root module outputs used for deployment verification and downstream configuration.

# Networking outputs
output "vpc_id" {
  value = module.networking.vpc_id
}
output "vpc_cidr" {
  value = module.networking.vpc_cidr
}
output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}
output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}
output "nat_gateway_public_ips" {
  value = module.networking.nat_gateway_public_ips
}
output "secrets_manager_endpoint_dns_name" {
  value = module.security.secrets_manager_endpoint_dns_name
}

# Oracle tunnel gateway outputs
output "tunnel_gateway_instance_id" {
  value = module.tunnel_gateway.instance_id
}
output "tunnel_gateway_public_ip" {
  value = module.tunnel_gateway.public_ip
}
output "tunnel_gateway_private_ip" {
  value = module.tunnel_gateway.private_ip
}
output "tunnel_listen_port" {
  value = var.tunnel_listen_port
}

# Secrets Manager outputs
output "oracle_source_secret_arn" {
  value       = module.secrets.oracle_source_secret_arn
  description = "Empty Secrets Manager container; populate outside Terraform before enabling DMS endpoints."
}

output "postgres_dms_target_secret_arn" {
  value       = module.secrets.postgres_target_secret_arn
  description = "Empty least-privilege PostgreSQL DMS target secret; populate outside Terraform after creating the DMS target database user."
}

# PostgreSQL outputs
output "postgres_instance_identifier" {
  value = module.postgres.instance_identifier
}
output "postgres_endpoint_address" {
  value = module.postgres.address
}
output "postgres_endpoint_port" {
  value = module.postgres.port
}
output "postgres_database_name" {
  value = var.postgres_database_name
}
output "postgres_master_secret_arn" {
  value       = module.postgres.master_user_secret_arn
  description = "RDS-managed master credential secret ARN for DBA/bootstrap use only; do not use it for DMS endpoint authentication."
  sensitive   = true
}

# DMS outputs
output "dms_replication_instance_id" {
  value = module.dms.replication_instance_id
}
output "dms_replication_instance_arn" {
  value = module.dms.replication_instance_arn
}
output "dms_source_endpoint_arn" {
  value = module.dms.source_endpoint_arn
}
output "dms_target_endpoint_arn" {
  value = module.dms.target_endpoint_arn
}
output "dms_replication_task_arn" {
  value = module.dms.replication_task_arn
}

# Shared infrastructure outputs
output "artifacts_bucket_name" {
  value = module.artifacts.bucket_name
}
output "kms_key_arn" {
  value = module.kms.kms_key_arn
}

# Schema conversion outputs
output "schema_conversion_project_arn" {
  value       = var.enable_schema_conversion_project ? module.schema_conversion[0].migration_project_arn : null
  description = "Populated only when enable_schema_conversion_project=true."
}

output "oracle_schema_conversion_secret_arn" {
  value       = module.secrets.oracle_schema_conversion_secret_arn
  description = "Empty Secrets Manager container for a separate Oracle Schema Conversion metadata user; populate only if online Schema Conversion is enabled."
}
