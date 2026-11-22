
# Stores Oracle DMS source credentials in Secrets Manager; the secret value is populated outside Terraform.
resource "aws_secretsmanager_secret" "oracle_source" {
  name                    = "${var.project_name}/${var.environment}/oracle-source-endpoint"
  description             = "Credentials for the Oracle MIGPDB AWS DMS Full Load + CDC source endpoint using DMS_USER. Secret value is populated outside Terraform."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.project_name}-${var.environment}-oracle-source-secret" })
}

# Stores least-privilege PostgreSQL DMS target credentials in Secrets Manager.
resource "aws_secretsmanager_secret" "postgres_target" {
  name                    = "${var.project_name}/${var.environment}/postgres-dms-target"
  description             = "Least-privilege PostgreSQL DMS target credentials. Secret value is populated outside Terraform."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.project_name}-${var.environment}-postgres-dms-target-secret" })
}

# Stores separate Oracle metadata credentials for optional DMS Schema Conversion assessments.
resource "aws_secretsmanager_secret" "oracle_schema_conversion" {
  name                    = "${var.project_name}/${var.environment}/oracle-schema-conversion-source"
  description             = "Separate Oracle metadata account for optional DMS Schema Conversion online assessment. Populate outside Terraform after granting documented metadata privileges."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.project_name}-${var.environment}-oracle-schema-conversion-secret" })
}
