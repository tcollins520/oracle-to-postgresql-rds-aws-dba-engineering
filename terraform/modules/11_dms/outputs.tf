# Outputs exposed by the reusable Dms module.

output "replication_instance_id" {
  value = aws_dms_replication_instance.this.replication_instance_id
}
output "replication_instance_arn" {
  value = aws_dms_replication_instance.this.replication_instance_arn
}
output "replication_subnet_group_id" {
  value = aws_dms_replication_subnet_group.this.id
}
output "source_endpoint_arn" {
  value = try(aws_dms_endpoint.oracle_source[0].endpoint_arn, null)
}
output "target_endpoint_arn" {
  value = try(aws_dms_endpoint.postgres_target[0].endpoint_arn, null)
}
output "replication_task_arn" {
  value = try(aws_dms_replication_task.full_load_cdc[0].replication_task_arn, null)
}
