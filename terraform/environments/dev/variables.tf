# Environment-level inputs. Set deployment-specific values in the local tfvars file.

variable "project_name" {
  description = "Project identifier used in AWS resource names and tags."
  type        = string
  default     = "oracle-postgresql-migration"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS deployment Region."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Dedicated migration VPC CIDR. Confirm it does not overlap any existing or connected networks."
  type        = string
  default     = "10.60.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs keyed by az_a and az_b."
  type        = map(string)
  default = {
    az_a = "10.60.1.0/24"
    az_b = "10.60.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs keyed by az_a and az_b."
  type        = map(string)
  default = {
    az_a = "10.60.11.0/24"
    az_b = "10.60.12.0/24"
  }
}

variable "enable_nat_gateway" {
  description = "Optional NAT Gateway for private-subnet public internet egress. Not required by the base DMS design because S3 and Secrets Manager use VPC endpoints."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "When NAT is enabled, use one NAT Gateway across both AZs for lower development cost; false creates one NAT Gateway per AZ."
  type        = bool
  default     = true
}

variable "oracle_source_cidr" {
  description = "Current public egress IPv4 CIDR of the Oracle RHEL VM, normally /32. Reconfirm immediately before apply."
  type        = string
  validation {
    condition     = can(cidrhost(var.oracle_source_cidr, 0)) && endswith(var.oracle_source_cidr, "/32")
    error_message = "oracle_source_cidr must be a single IPv4 address with /32, for example 203.0.113.10/32."
  }
}

variable "tunnel_public_key" {
  description = "OpenSSH public key for the restricted oracle-tunnel account. Never provide the private key."
  type        = string
  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) ", trimspace(var.tunnel_public_key)))
    error_message = "Provide an OpenSSH public key; ssh-ed25519 is recommended."
  }
}

variable "tunnel_gateway_private_ip" {
  description = "Fixed private IP for the EC2 reverse-tunnel gateway in public subnet az_a."
  type        = string
  default     = "10.60.1.10"
}

variable "tunnel_listen_port" {
  description = "Private VPC TCP port on which the gateway accepts the reverse-tunnel stream from DMS."
  type        = number
  default     = 11521
  validation {
    condition     = var.tunnel_listen_port >= 1024 && var.tunnel_listen_port <= 65535
    error_message = "tunnel_listen_port must be between 1024 and 65535."
  }
}

variable "tunnel_instance_type" {
  description = "EC2 instance class for the lightweight SSH tunnel gateway."
  type        = string
  default     = "t3.micro"
}

variable "postgres_engine_version" {
  description = "Amazon RDS for PostgreSQL engine version. Verify it is orderable in this account and Region before apply."
  type        = string
  default     = "18.6"
}

variable "postgres_instance_class" {
  description = "Amazon RDS instance class. Verify orderability for PostgreSQL 18.6 and Multi-AZ in us-east-1 before apply."
  type        = string
  default     = "db.t3.medium"
}

variable "postgres_database_name" {
  description = "Initial PostgreSQL database name for the Oracle migration."
  type        = string
  default     = "oracle_migration"
}

variable "postgres_master_username" {
  description = "RDS-managed master username. Create separate least-privilege DMS/application users after deployment."
  type        = string
  default     = "migration_admin"
}

variable "postgres_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 30
}

variable "postgres_max_allocated_storage" {
  description = "Maximum autoscaled RDS storage in GiB."
  type        = number
  default     = 100
}

variable "postgres_multi_az" {
  description = "Deploy the RDS PostgreSQL DB instance with a Multi-AZ standby."
  type        = bool
  default     = true
}

variable "postgres_backup_retention_days" {
  description = "RDS automated backup retention in days."
  type        = number
  default     = 7
}

variable "postgres_deletion_protection" {
  description = "Protect the RDS target against accidental deletion."
  type        = bool
  default     = true
}

variable "dms_replication_instance_class" {
  description = "AWS DMS replication instance class. Size after endpoint tests and throughput review."
  type        = string
  default     = "dms.t3.medium"
}

variable "dms_multi_az" {
  description = "Use a Multi-AZ DMS replication instance. Disabled by default as a migration development cost tradeoff."
  type        = bool
  default     = false
}

variable "dms_allocated_storage" {
  description = "DMS replication instance storage in GiB."
  type        = number
  default     = 50
}

variable "manage_dms_vpc_role" {
  description = "Create the account-level dms-vpc-role. Set false only if an equivalent role already exists and is correctly configured."
  type        = bool
  default     = true
}

variable "manage_dms_cloudwatch_logs_role" {
  description = "Create the account-level dms-cloudwatch-logs-role. Set false only if an equivalent role already exists and is correctly configured."
  type        = bool
  default     = true
}

variable "create_dms_endpoints" {
  description = "Create DMS source and target endpoints only after the Oracle secret is populated and the tunnel is tested."
  type        = bool
  default     = false
}

variable "create_dms_task" {
  description = "Create (but do not start) the Full Load + CDC task after endpoints and target schema are ready."
  type        = bool
  default     = false
}

variable "enable_schema_conversion_project" {
  description = "Create the serverless DMS Schema Conversion project after both endpoint secrets and network connectivity are ready."
  type        = bool
  default     = false
}

variable "source_oracle_service_name" {
  description = "Oracle PDB service name used by the DMS source endpoint."
  type        = string
  default     = "migpdb"
}

variable "source_oracle_database_name" {
  description = "Oracle PDB service/database identifier used by the DMS Schema Conversion data provider."
  type        = string
  default     = "MIGPDB"
}

variable "source_schemas" {
  description = "Oracle application schemas included by the DMS table-mapping selection rules."
  type        = list(string)
  default     = ["COMMON", "FINANCE", "GRANTS", "PROCUREMENT"]
}

variable "notification_email" {
  description = "Optional email address for CloudWatch alarm notifications. Leave empty to create the SNS topic without a subscription."
  type        = string
  default     = ""
}
