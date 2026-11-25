
# DMS table mappings, replication settings, and endpoint connectivity.
locals {
  table_mappings = jsonencode({
    rules = concat(
      [
        for index, schema in var.source_schemas : {
          "rule-type" = "selection"
          "rule-id"   = tostring(index + 1)
          "rule-name" = "include-${lower(schema)}"
          "object-locator" = {
            "schema-name" = schema
            "table-name"  = "%"
          }
          "rule-action" = "include"
        }
      ],
      flatten([
        for index, schema in var.source_schemas : [
          {
            "rule-type"   = "transformation"
            "rule-id"     = tostring(100 + index * 3)
            "rule-name"   = "lowercase-schema-${lower(schema)}"
            "rule-target" = "schema"
            "object-locator" = {
              "schema-name" = schema
            }
            "rule-action" = "convert-lowercase"
          },
          {
            "rule-type"   = "transformation"
            "rule-id"     = tostring(101 + index * 3)
            "rule-name"   = "lowercase-tables-${lower(schema)}"
            "rule-target" = "table"
            "object-locator" = {
              "schema-name" = schema
              "table-name"  = "%"
            }
            "rule-action" = "convert-lowercase"
          },
          {
            "rule-type"   = "transformation"
            "rule-id"     = tostring(102 + index * 3)
            "rule-name"   = "lowercase-columns-${lower(schema)}"
            "rule-target" = "column"
            "object-locator" = {
              "schema-name" = schema
              "table-name"  = "%"
              "column-name" = "%"
            }
            "rule-action" = "convert-lowercase"
          }
        ]
      ])
    )
  })

  task_settings = jsonencode({
    Logging = {
      EnableLogging = true
    }
    FullLoadSettings = {
      TargetTablePrepMode             = "DO_NOTHING"
      CreatePkAfterFullLoad           = false
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks             = 2
      TransactionConsistencyTimeout   = 600
      CommitRate                      = 10000
    }
  })

  secrets_manager_override = "secretsManagerEndpointOverride=${var.secrets_manager_endpoint_dns_name};"
}

# Defines the private subnets used by DMS.
resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id          = "${var.project_name}-${var.environment}-dms-private-subnets"
  replication_subnet_group_description = "Private two-AZ subnet group for AWS DMS replication and Schema Conversion."
  subnet_ids                           = var.private_subnet_ids
  tags                                 = merge(var.tags, { Name = "${var.project_name}-${var.environment}-dms-private-subnets" })
}

# Provisions the private DMS replication instance.
resource "aws_dms_replication_instance" "this" {
  replication_instance_id     = "${var.project_name}-${var.environment}-replication"
  replication_instance_class  = var.replication_instance_class
  allocated_storage           = var.allocated_storage
  replication_subnet_group_id = aws_dms_replication_subnet_group.this.id
  vpc_security_group_ids      = [var.dms_security_group_id]
  kms_key_arn                 = var.kms_key_arn
  publicly_accessible         = false
  multi_az                    = var.replication_multi_az
  apply_immediately           = false
  auto_minor_version_upgrade  = true

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-replication" })
}

# Configures the Oracle MIGPDB source endpoint.
resource "aws_dms_endpoint" "oracle_source" {
  count = var.create_endpoints ? 1 : 0

  endpoint_id                     = "${var.project_name}-${var.environment}-oracle-source"
  endpoint_type                   = "source"
  engine_name                     = "oracle"
  database_name                   = var.oracle_service_name
  secrets_manager_arn             = var.oracle_source_secret_arn
  secrets_manager_access_role_arn = var.endpoint_secrets_role_arn
  kms_key_arn                     = var.kms_key_arn
  extra_connection_attributes     = "useLogMinerReader=N;useBfile=Y;${local.secrets_manager_override}"
  ssl_mode                        = "none"

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-oracle-source" })
}

# Configures the Amazon RDS PostgreSQL target endpoint.
resource "aws_dms_endpoint" "postgres_target" {
  count = var.create_endpoints ? 1 : 0

  endpoint_id                     = "${var.project_name}-${var.environment}-postgres-target"
  endpoint_type                   = "target"
  engine_name                     = "postgres"
  database_name                   = var.postgres_database_name
  secrets_manager_arn             = var.postgres_secret_arn
  secrets_manager_access_role_arn = var.endpoint_secrets_role_arn
  kms_key_arn                     = var.kms_key_arn
  extra_connection_attributes     = local.secrets_manager_override
  ssl_mode                        = "require"

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-postgres-target" })
}

# Creates the Full Load and CDC task without starting it.
resource "aws_dms_replication_task" "full_load_cdc" {
  count = var.create_task && var.create_endpoints ? 1 : 0

  replication_task_id       = "${var.project_name}-${var.environment}-full-load-cdc"
  migration_type            = "full-load-and-cdc"
  replication_instance_arn  = aws_dms_replication_instance.this.replication_instance_arn
  source_endpoint_arn       = aws_dms_endpoint.oracle_source[0].endpoint_arn
  target_endpoint_arn       = aws_dms_endpoint.postgres_target[0].endpoint_arn
  table_mappings            = local.table_mappings
  replication_task_settings = local.task_settings
  start_replication_task    = false

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-full-load-cdc" })
}