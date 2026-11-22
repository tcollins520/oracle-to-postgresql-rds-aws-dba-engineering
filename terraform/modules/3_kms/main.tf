# KMS encryption key and access policies.

# Retrieves the current AWS account, region, and partition.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Defines account and CloudWatch permissions for the KMS key.
data "aws_iam_policy_document" "key_policy" {
  statement {
    sid    = "EnableAccountRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchAlarmsToUseKeyForSNS"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${var.environment}-*"
      ]
    }
  }
}

# Creates the customer-managed encryption key.
resource "aws_kms_key" "this" {
  description             = "Customer-managed encryption key for Oracle-to-RDS PostgreSQL migration."
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.key_policy.json
  tags                    = merge(var.tags, { Name = "${var.project_name}-${var.environment}-key" })

  lifecycle {
    prevent_destroy = true
  }
}

# Creates the KMS key alias.
resource "aws_kms_alias" "this" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.this.key_id
}