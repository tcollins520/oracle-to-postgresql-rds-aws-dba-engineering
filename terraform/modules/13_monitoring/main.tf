# CloudWatch alarms and SNS notifications.

# Creates the encrypted SNS notification topic.
resource "aws_sns_topic" "alarms" {
  name              = "${var.project_name}-${var.environment}-alarms"
  kms_master_key_id = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.project_name}-${var.environment}-alarms" })
}

# Retrieves the current AWS account, region, and partition.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Allows CloudWatch alarms in this project to publish to SNS.
data "aws_iam_policy_document" "alarms_topic" {
  statement {
    sid    = "AllowCloudWatchAlarmsToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

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

# Applies the CloudWatch publishing policy to SNS.
resource "aws_sns_topic_policy" "alarms" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.alarms_topic.json
}

# Subscribes the configured email address to SNS notifications.
resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Monitors PostgreSQL CPU utilization.
resource "aws_cloudwatch_metric_alarm" "postgres_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-postgres-cpu-high"
  alarm_description   = "RDS PostgreSQL average CPU is above 80 percent for three 5-minute periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions          = { DBInstanceIdentifier = var.postgres_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

# Monitors PostgreSQL free storage.
resource "aws_cloudwatch_metric_alarm" "postgres_free_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-postgres-low-storage"
  alarm_description   = "RDS PostgreSQL free storage is below 5 GiB."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = 5368709120
  dimensions          = { DBInstanceIdentifier = var.postgres_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

# Monitors DMS replication instance CPU utilization.
resource "aws_cloudwatch_metric_alarm" "dms_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-dms-cpu-high"
  alarm_description   = "DMS replication-instance CPU is above 80 percent for three 5-minute periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DMS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions          = { ReplicationInstanceIdentifier = var.dms_replication_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

# Monitors DMS replication instance free storage.
resource "aws_cloudwatch_metric_alarm" "dms_free_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-dms-low-storage"
  alarm_description   = "DMS replication-instance free storage is below 10 GiB."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/DMS"
  period              = 300
  statistic           = "Minimum"
  threshold           = 10737418240
  dimensions          = { ReplicationInstanceIdentifier = var.dms_replication_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

# Monitors the EC2 tunnel gateway status checks.
resource "aws_cloudwatch_metric_alarm" "tunnel_status_check" {
  alarm_name          = "${var.project_name}-${var.environment}-tunnel-status-check"
  alarm_description   = "EC2 tunnel gateway system or instance status check failed."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  dimensions          = { InstanceId = var.tunnel_gateway_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}