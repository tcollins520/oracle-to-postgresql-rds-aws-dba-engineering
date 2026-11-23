
# IAM roles and permissions for DMS, Schema Conversion, and EC2.

# Defines the EC2 trust policy.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Creates the EC2 Systems Manager role.
resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.project_name}-${var.environment}-tunnel-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = merge(var.tags, { Name = "${var.project_name}-${var.environment}-tunnel-ssm-role" })
}

# Attaches the Systems Manager managed policy.
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Creates the EC2 instance profile.
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-${var.environment}-tunnel-instance-profile"
  role = aws_iam_role.ec2_ssm.name
  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-tunnel-instance-profile" })
}

# Defines the DMS service trust policy.
data "aws_iam_policy_document" "dms_service_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

# Defines the DMS regional trust policy.
data "aws_iam_policy_document" "dms_regional_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dms.${var.aws_region}.amazonaws.com"]
    }
  }
}

# Defines the Schema Conversion secrets trust policy.
data "aws_iam_policy_document" "schema_conversion_secrets_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "schema-conversion.dms.amazonaws.com",
        "dms.${var.aws_region}.amazonaws.com"
      ]
    }
  }
}

# Defines the Schema Conversion S3 trust policy.
data "aws_iam_policy_document" "schema_conversion_s3_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "schema-conversion.dms.amazonaws.com",
        "dms.${var.aws_region}.amazonaws.com"
      ]
    }
  }
}

# Creates the account-level DMS VPC role.
resource "aws_iam_role" "dms_vpc" {
  count              = var.manage_dms_vpc_role ? 1 : 0
  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_service_assume_role.json
  tags               = merge(var.tags, { Name = "dms-vpc-role" })
}

# Attaches the DMS VPC management policy.
resource "aws_iam_role_policy_attachment" "dms_vpc" {
  count      = var.manage_dms_vpc_role ? 1 : 0
  role       = aws_iam_role.dms_vpc[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# Creates the account-level DMS CloudWatch role.
resource "aws_iam_role" "dms_cloudwatch" {
  count              = var.manage_dms_cloudwatch_logs_role ? 1 : 0
  name               = "dms-cloudwatch-logs-role"
  assume_role_policy = data.aws_iam_policy_document.dms_service_assume_role.json
  tags               = merge(var.tags, { Name = "dms-cloudwatch-logs-role" })
}

# Attaches the DMS CloudWatch logging policy.
resource "aws_iam_role_policy_attachment" "dms_cloudwatch" {
  count      = var.manage_dms_cloudwatch_logs_role ? 1 : 0
  role       = aws_iam_role.dms_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# Looks up the existing DMS VPC role.
data "aws_iam_role" "dms_vpc_existing" {
  count = var.manage_dms_vpc_role ? 0 : 1
  name  = "dms-vpc-role"
}

# Looks up the existing DMS CloudWatch role.
data "aws_iam_role" "dms_cloudwatch_existing" {
  count = var.manage_dms_cloudwatch_logs_role ? 0 : 1
  name  = "dms-cloudwatch-logs-role"
}

# Selects the managed or existing DMS role ARNs.
locals {
  dms_vpc_role_arn        = var.manage_dms_vpc_role ? aws_iam_role.dms_vpc[0].arn : data.aws_iam_role.dms_vpc_existing[0].arn
  dms_cloudwatch_role_arn = var.manage_dms_cloudwatch_logs_role ? aws_iam_role.dms_cloudwatch[0].arn : data.aws_iam_role.dms_cloudwatch_existing[0].arn
}

# Creates the DMS endpoint Secrets Manager role.
resource "aws_iam_role" "dms_endpoint_secrets" {
  name               = "${var.project_name}-${var.environment}-dms-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.dms_regional_assume_role.json
  tags               = merge(var.tags, { Name = "${var.project_name}-${var.environment}-dms-secrets-role" })
}

# Defines access to Oracle and PostgreSQL endpoint secrets.
data "aws_iam_policy_document" "dms_endpoint_secrets" {
  statement {
    sid       = "ReadEndpointCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.oracle_source_secret_arn, var.postgres_secret_arn]
  }

  statement {
    sid       = "DecryptEndpointSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

# Attaches endpoint secret access permissions to DMS.
resource "aws_iam_role_policy" "dms_endpoint_secrets" {
  name   = "${var.project_name}-${var.environment}-dms-secrets-policy"
  role   = aws_iam_role.dms_endpoint_secrets.id
  policy = data.aws_iam_policy_document.dms_endpoint_secrets.json
}

# Creates the Schema Conversion Secrets Manager role.
resource "aws_iam_role" "schema_conversion_secrets" {
  name               = "${var.project_name}-${var.environment}-schema-conversion-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.schema_conversion_secrets_assume_role.json
  tags               = merge(var.tags, { Name = "${var.project_name}-${var.environment}-schema-conversion-secrets-role" })
}

# Defines access to Schema Conversion database credentials.
data "aws_iam_policy_document" "schema_conversion_secrets" {
  statement {
    sid       = "ReadSchemaConversionEndpointCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.oracle_schema_conversion_secret_arn, var.postgres_master_secret_arn]
  }

  statement {
    sid       = "DecryptSchemaConversionEndpointSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

# Attaches Schema Conversion secret access permissions.
resource "aws_iam_role_policy" "schema_conversion_secrets" {
  name   = "${var.project_name}-${var.environment}-schema-conversion-secrets-policy"
  role   = aws_iam_role.schema_conversion_secrets.id
  policy = data.aws_iam_policy_document.schema_conversion_secrets.json
}

# Creates the Schema Conversion S3 access role.
resource "aws_iam_role" "schema_conversion_s3" {
  name               = "${var.project_name}-${var.environment}-dms-schema-s3-role"
  assume_role_policy = data.aws_iam_policy_document.schema_conversion_s3_assume_role.json
  tags               = merge(var.tags, { Name = "${var.project_name}-${var.environment}-dms-schema-s3-role" })
}

# Defines S3 and KMS permissions for Schema Conversion artifacts.
data "aws_iam_policy_document" "schema_conversion_s3" {
  statement {
    sid    = "ListMigrationArtifactsBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning"
    ]

    resources = [var.artifacts_bucket_arn]
  }

  statement {
    sid    = "ReadWriteSchemaConversionArtifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]

    resources = ["${var.artifacts_bucket_arn}/*"]
  }

  statement {
    sid    = "UseMigrationKmsKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]

    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }
}

# Attaches S3 and KMS artifact access permissions.
resource "aws_iam_role_policy" "schema_conversion_s3" {
  name   = "${var.project_name}-${var.environment}-dms-schema-s3-policy"
  role   = aws_iam_role.schema_conversion_s3.id
  policy = data.aws_iam_policy_document.schema_conversion_s3.json
}
