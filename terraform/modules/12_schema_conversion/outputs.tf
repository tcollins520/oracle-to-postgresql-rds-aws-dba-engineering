# Outputs exposed by the reusable Schema Conversion module.

output "migration_project_arn" {
  value = awscc_dms_migration_project.this.migration_project_arn
}
output "oracle_data_provider_arn" {
  value = awscc_dms_data_provider.oracle.data_provider_arn
}
output "postgres_data_provider_arn" {
  value = awscc_dms_data_provider.postgres.data_provider_arn
}
output "instance_profile_arn" {
  value = awscc_dms_instance_profile.this.instance_profile_arn
}
