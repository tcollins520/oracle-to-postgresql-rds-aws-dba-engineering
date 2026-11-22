# Outputs exposed by the reusable Security module.

output "tunnel_security_group_id" {
  value = aws_security_group.tunnel.id
}
output "dms_security_group_id" {
  value = aws_security_group.dms.id
}
output "postgres_security_group_id" {
  value = aws_security_group.postgres.id
}
output "secrets_manager_endpoint_id" {
  value = aws_vpc_endpoint.secretsmanager.id
}
output "secrets_manager_endpoint_dns_name" {
  value       = aws_vpc_endpoint.secretsmanager.dns_entry[0].dns_name
  description = "Regional interface-endpoint DNS name for the DMS secretsManagerEndpointOverride attribute."
}
