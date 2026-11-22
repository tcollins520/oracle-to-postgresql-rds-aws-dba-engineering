# ==========================================================
# Amazon RDS for PostgreSQL instance
# ==========================================================

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  db_name        = var.database_name
  username       = var.master_username
  port           = 5432

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  multi_az               = var.multi_az
  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  parameter_group_name   = var.parameter_group_name

  backup_retention_period         = var.backup_retention_days
  copy_tags_to_snapshot           = true
  auto_minor_version_upgrade      = false
  apply_immediately               = false
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-postgres-final"

  tags = merge(var.tags, {
    Name   = "${var.project_name}-${var.environment}-postgres"
    Engine = "PostgreSQL ${var.engine_version}"
    Role   = "Oracle migration target"
  })
}
