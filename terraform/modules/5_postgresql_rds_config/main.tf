# ==========================================================
# PostgreSQL DB parameter group
# ==========================================================

resource "aws_db_parameter_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres18-parameters"
  family      = "postgres18"
  description = "PostgreSQL 18 parameter group for the Oracle migration target."
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-postgres18-parameters" })

  lifecycle {
    create_before_destroy = true
  }
}
