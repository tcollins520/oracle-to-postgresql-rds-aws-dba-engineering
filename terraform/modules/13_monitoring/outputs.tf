# Outputs exposed by the reusable Monitoring module.

output "sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}
