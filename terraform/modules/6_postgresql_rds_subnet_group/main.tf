# ==========================================================
# Private PostgreSQL DB subnet group
# ==========================================================
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres-subnets"
  description = "Private subnet group for the Oracle migration PostgreSQL target."
  subnet_ids  = var.private_subnet_ids
  tags        = merge(var.tags, { Name = "${var.project_name}-${var.environment}-postgres-subnets" })
}
