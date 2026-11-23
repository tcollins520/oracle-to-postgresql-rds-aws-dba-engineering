# Security groups and VPC endpoints for the Oracle-to-PostgreSQL migration.

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# Security group for the Oracle reverse SSH tunnel gateway.
resource "aws_security_group" "tunnel" {
  name        = "${var.project_name}-${var.environment}-tunnel-sg"
  description = "SSH reverse-tunnel gateway. SSH from Oracle source and tunnel listener from DMS only."
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-tunnel-sg" })
}

# Security group for the AWS DMS replication instance.
resource "aws_security_group" "dms" {
  name        = "${var.project_name}-${var.environment}-dms-sg"
  description = "Private AWS DMS replication connectivity."
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-dms-sg" })
}

# Security group for the private PostgreSQL RDS instance.
resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres-sg"
  description = "Private PostgreSQL access from DMS and the SSM-managed gateway only."
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-postgres-sg" })
}

# Security group for the Secrets Manager interface endpoint.
resource "aws_security_group" "secretsmanager_endpoint" {
  name        = "${var.project_name}-${var.environment}-secretsmanager-vpce-sg"
  description = "HTTPS access to the Secrets Manager interface endpoint from AWS DMS only."
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-secretsmanager-vpce-sg" })
}

# Allow SSH connections from the Oracle source VM.
resource "aws_vpc_security_group_ingress_rule" "tunnel_ssh_from_oracle" {
  security_group_id = aws_security_group.tunnel.id
  cidr_ipv4         = var.oracle_source_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH initiated outbound from the Oracle RHEL VM public egress IP."
}

# Allow DMS to access the reverse SSH tunnel listener.
resource "aws_vpc_security_group_ingress_rule" "tunnel_from_dms" {
  security_group_id            = aws_security_group.tunnel.id
  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = var.tunnel_listen_port
  to_port                      = var.tunnel_listen_port
  ip_protocol                  = "tcp"
  description                  = "Only the DMS security group can reach the reverse SSH forwarding listener."
}

# Allow HTTPS outbound traffic from the tunnel gateway.
resource "aws_vpc_security_group_egress_rule" "tunnel_https" {
  security_group_id = aws_security_group.tunnel.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS outbound for Systems Manager and package repositories."
}

# Allow the tunnel gateway to connect to PostgreSQL.
resource "aws_vpc_security_group_egress_rule" "tunnel_to_postgres" {
  security_group_id            = aws_security_group.tunnel.id
  referenced_security_group_id = aws_security_group.postgres.id
  from_port                    = var.postgres_port
  to_port                      = var.postgres_port
  ip_protocol                  = "tcp"
  description                  = "Optional SSM-based PostgreSQL administration from the gateway."
}

# Allow outbound connectivity required by AWS DMS.
resource "aws_vpc_security_group_egress_rule" "dms_all" {
  security_group_id = aws_security_group.dms.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound connectivity required by AWS DMS."
}

# Allow DMS to access the Secrets Manager interface endpoint.
resource "aws_vpc_security_group_ingress_rule" "secretsmanager_https_from_dms" {
  security_group_id            = aws_security_group.secretsmanager_endpoint.id
  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "AWS DMS access to endpoint credentials through the Secrets Manager interface endpoint."
}

# Allow PostgreSQL connections from the DMS replication instance.
resource "aws_vpc_security_group_ingress_rule" "postgres_from_dms" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = var.postgres_port
  to_port                      = var.postgres_port
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL access from the DMS replication instance."
}

# Allow PostgreSQL administration from the tunnel gateway.
resource "aws_vpc_security_group_ingress_rule" "postgres_from_tunnel" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.tunnel.id
  from_port                    = var.postgres_port
  to_port                      = var.postgres_port
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL administration from the SSM-managed gateway."
}

# Create a private Secrets Manager interface endpoint.
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.secretsmanager_endpoint.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-secretsmanager-vpce"
  })
}