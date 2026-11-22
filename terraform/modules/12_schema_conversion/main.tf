
# Converts Terraform tags into the format required by AWS Cloud Control resources.
locals {
  awscc_tags = [for key, value in var.tags : { key = key, value = value }]
}

# Registers the Oracle 19c MIGPDB source for DMS Schema Conversion.
resource "awscc_dms_data_provider" "oracle" {
  data_provider_name       = "${var.project_name}-${var.environment}-oracle-source"
  data_provider_identifier = "${var.project_name}-${var.environment}-oracle-source"
  description              = "Oracle-19c-MIGPDB-source"
  engine                   = "oracle"
  exact_settings           = false
  settings = {
    oracle_settings = {
      server_name   = var.oracle_server_name
      port          = var.oracle_port
      database_name = var.oracle_service_name
      ssl_mode      = "none"
    }
  }
  tags = local.awscc_tags
}

# Registers the Amazon RDS for PostgreSQL target for schema conversion.
resource "awscc_dms_data_provider" "postgres" {
  data_provider_name       = "${var.project_name}-${var.environment}-postgres-target"
  data_provider_identifier = "${var.project_name}-${var.environment}-postgres-target"
  description              = "RDS-PostgreSQL-target"
  engine                   = "postgres"
  exact_settings           = false
  settings = {
    postgre_sql_settings = {
      server_name   = var.postgres_server_name
      port          = 5432
      database_name = var.postgres_database_name
      ssl_mode      = "require"
    }
  }
  tags = local.awscc_tags
}

# Creates the private network profile used by the Schema Conversion project.
resource "awscc_dms_instance_profile" "this" {
  instance_profile_identifier = "${var.project_name}-${var.environment}-sc-profile"
  instance_profile_name       = "${var.project_name}-${var.environment}-sc-profile"
  description                 = "Private-IPv4-SC-profile"
  network_type                = "IPV4"
  publicly_accessible         = false
  subnet_group_identifier     = var.schema_conversion_subnet_group_id
  vpc_security_groups         = [var.dms_security_group_id]
  kms_key_arn                 = var.kms_key_arn
  tags                        = local.awscc_tags
}

# Creates the Oracle-to-PostgreSQL DMS Schema Conversion migration project.
resource "awscc_dms_migration_project" "this" {
  migration_project_identifier = "${var.project_name}-${var.environment}-oracle-pg-sc"
  migration_project_name       = "${var.project_name}-${var.environment}-oracle-pg-sc"
  description                  = "Oracle-to-RDS-PostgreSQL-schema-conversion"
  instance_profile_identifier  = "${var.project_name}-${var.environment}-sc-profile"

  source_data_provider_descriptors = [{
    data_provider_arn               = awscc_dms_data_provider.oracle.data_provider_arn
    data_provider_name              = awscc_dms_data_provider.oracle.data_provider_name
    secrets_manager_secret_id       = var.oracle_secret_arn
    secrets_manager_access_role_arn = var.secrets_access_role_arn
  }]

  target_data_provider_descriptors = [{
    data_provider_arn               = awscc_dms_data_provider.postgres.data_provider_arn
    data_provider_name              = awscc_dms_data_provider.postgres.data_provider_name
    secrets_manager_secret_id       = var.postgres_secret_arn
    secrets_manager_access_role_arn = var.secrets_access_role_arn
  }]

  schema_conversion_application_attributes = {
    s3_bucket_path     = "s3://${var.schema_conversion_bucket_name}/schema-conversion"
    s3_bucket_role_arn = var.schema_conversion_s3_role_arn
  }

  tags = local.awscc_tags
}
