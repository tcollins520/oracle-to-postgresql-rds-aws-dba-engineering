# Root module: provisions the PostgreSQL migration AWS infrastructure.

# ==========================================================
# Module 1: Networking
# ==========================================================

module "networking" {
  source = "../../modules/1_networking"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = { az_a = local.azs[0], az_b = local.azs[1] }
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.common_tags
}

# ==========================================================
# Module 2: Network Security
# ==========================================================

module "security" {
  source = "../../modules/2_security"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = values(module.networking.private_subnet_ids)
  oracle_source_cidr = var.oracle_source_cidr
  tunnel_listen_port = var.tunnel_listen_port
  postgres_port      = 5432
  tags               = local.common_tags
}

# ==========================================================
# Module 3: KMS Encryption
# ==========================================================

module "kms" {
  source = "../../modules/3_kms"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ==========================================================
# Module 4: S3 Migration Artifacts
# ==========================================================

module "artifacts" {
  source = "../../modules/4_s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = local.artifacts_bucket_name
  kms_key_arn  = module.kms.kms_key_arn
  tags         = local.common_tags
}

# ==========================================================
# Module 5: PostgreSQL Parameter Group
# ==========================================================

module "postgres_configuration" {
  source = "../../modules/5_postgresql_rds_config"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ==========================================================
# Module 6: PostgreSQL DB Subnet Group
# ==========================================================

module "postgres_subnet_group" {
  source = "../../modules/6_postgresql_rds_subnet_group"

  project_name       = var.project_name
  environment        = var.environment
  private_subnet_ids = values(module.networking.private_subnet_ids)
  tags               = local.common_tags
}

# ==========================================================
# Module 7: Amazon RDS for PostgreSQL
# ==========================================================

module "postgres" {
  source = "../../modules/7_postgresql_rds_instance"

  project_name          = var.project_name
  environment           = var.environment
  database_name         = var.postgres_database_name
  master_username       = var.postgres_master_username
  engine_version        = var.postgres_engine_version
  instance_class        = var.postgres_instance_class
  allocated_storage     = var.postgres_allocated_storage
  max_allocated_storage = var.postgres_max_allocated_storage
  multi_az              = var.postgres_multi_az
  backup_retention_days = var.postgres_backup_retention_days
  deletion_protection   = var.postgres_deletion_protection
  subnet_group_name     = module.postgres_subnet_group.subnet_group_name
  security_group_id     = module.security.postgres_security_group_id
  parameter_group_name  = module.postgres_configuration.parameter_group_name
  kms_key_arn           = module.kms.kms_key_arn
  tags                  = local.common_tags
}

# ==========================================================
# Module 8: Secrets Manager
# ==========================================================

module "secrets" {
  source = "../../modules/8_secrets"

  project_name = var.project_name
  environment  = var.environment
  kms_key_arn  = module.kms.kms_key_arn
  tags         = local.common_tags
}

# ==========================================================
# Module 9: IAM Roles and Policies
# ==========================================================

module "iam" {
  source = "../../modules/9_iam"

  project_name                        = var.project_name
  environment                         = var.environment
  aws_region                          = var.aws_region
  kms_key_arn                         = module.kms.kms_key_arn
  artifacts_bucket_arn                = module.artifacts.bucket_arn
  oracle_source_secret_arn            = module.secrets.oracle_source_secret_arn
  postgres_secret_arn                 = module.secrets.postgres_target_secret_arn
  postgres_master_secret_arn          = module.postgres.master_user_secret_arn
  manage_dms_vpc_role                 = var.manage_dms_vpc_role
  manage_dms_cloudwatch_logs_role     = var.manage_dms_cloudwatch_logs_role
  oracle_schema_conversion_secret_arn = module.secrets.oracle_schema_conversion_secret_arn
  tags                                = local.common_tags
}

# ==========================================================
# Module 10: Oracle Reverse-Tunnel Gateway
# ==========================================================

module "tunnel_gateway" {
  source = "../../modules/10_ec2_tunnel_gateway"

  project_name          = var.project_name
  environment           = var.environment
  subnet_id             = module.networking.public_subnet_ids["az_a"]
  private_ip            = var.tunnel_gateway_private_ip
  security_group_id     = module.security.tunnel_security_group_id
  instance_profile_name = module.iam.ec2_instance_profile_name
  public_key            = var.tunnel_public_key
  instance_type         = var.tunnel_instance_type
  tunnel_listen_port    = var.tunnel_listen_port
  kms_key_arn           = module.kms.kms_key_arn
  tags                  = local.common_tags
}

# ==========================================================
# Module 11: AWS DMS Full Load and CDC
# ==========================================================

module "dms" {
  source = "../../modules/11_dms"

  project_name                      = var.project_name
  environment                       = var.environment
  private_subnet_ids                = values(module.networking.private_subnet_ids)
  dms_security_group_id             = module.security.dms_security_group_id
  kms_key_arn                       = module.kms.kms_key_arn
  endpoint_secrets_role_arn         = module.iam.dms_endpoint_secrets_role_arn
  oracle_source_secret_arn          = module.secrets.oracle_source_secret_arn
  postgres_secret_arn               = module.secrets.postgres_target_secret_arn
  secrets_manager_endpoint_dns_name = module.security.secrets_manager_endpoint_dns_name
  tunnel_listen_port                = var.tunnel_listen_port
  oracle_service_name               = var.source_oracle_service_name
  postgres_database_name            = var.postgres_database_name
  source_schemas                    = var.source_schemas
  replication_instance_class        = var.dms_replication_instance_class
  replication_multi_az              = var.dms_multi_az
  allocated_storage                 = var.dms_allocated_storage
  create_endpoints                  = var.create_dms_endpoints
  create_task                       = var.create_dms_task
  tags                              = local.common_tags

  depends_on = [module.iam]
}

# ==========================================================
# Module 12: AWS DMS Schema Conversion
# ==========================================================

module "schema_conversion" {
  source = "../../modules/12_schema_conversion"
  count  = var.enable_schema_conversion_project ? 1 : 0

  project_name                      = var.project_name
  environment                       = var.environment
  oracle_server_name                = module.tunnel_gateway.private_ip
  oracle_service_name               = var.source_oracle_service_name
  oracle_port                       = var.tunnel_listen_port
  oracle_secret_arn                 = module.secrets.oracle_schema_conversion_secret_arn
  postgres_server_name              = module.postgres.address
  postgres_database_name            = var.postgres_database_name
  postgres_secret_arn               = module.postgres.master_user_secret_arn
  secrets_access_role_arn           = module.iam.schema_conversion_secrets_role_arn
  schema_conversion_s3_role_arn     = module.iam.schema_conversion_s3_role_arn
  schema_conversion_bucket_name     = module.artifacts.bucket_name
  schema_conversion_subnet_group_id = module.dms.replication_subnet_group_id
  kms_key_arn                       = module.kms.kms_key_arn
  dms_security_group_id             = module.security.dms_security_group_id
  tags                              = local.common_tags

  depends_on = [module.dms, module.iam]
}

# ==========================================================
# Module 13: CloudWatch Monitoring and Notifications
# ==========================================================

module "monitoring" {
  source = "../../modules/13_monitoring"

  project_name                = var.project_name
  environment                 = var.environment
  postgres_instance_id        = module.postgres.instance_identifier
  dms_replication_instance_id = module.dms.replication_instance_id
  tunnel_gateway_instance_id  = module.tunnel_gateway.instance_id
  notification_email          = var.notification_email
  kms_key_arn                 = module.kms.kms_key_arn
  tags                        = local.common_tags
}
