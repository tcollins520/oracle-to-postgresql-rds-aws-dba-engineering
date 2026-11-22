# Outputs exposed by the reusable Iam module.

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_ssm.name
}
output "dms_vpc_role_arn" {
  value = local.dms_vpc_role_arn
}
output "dms_cloudwatch_role_arn" {
  value = local.dms_cloudwatch_role_arn
}
output "dms_endpoint_secrets_role_arn" {
  value = aws_iam_role.dms_endpoint_secrets.arn
}
output "schema_conversion_secrets_role_arn" {
  value = aws_iam_role.schema_conversion_secrets.arn
}
output "schema_conversion_s3_role_arn" {
  value = aws_iam_role.schema_conversion_s3.arn
}
