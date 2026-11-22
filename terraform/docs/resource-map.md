# Resource map and deployment dependencies

1. `networking`: VPC, two public subnets, two private subnets, IGW, optional NAT EIP/Gateways, per-AZ route tables, and S3 gateway endpoint.
2. `security`: three security groups and narrowly scoped ingress/egress rules.
3. `kms`: customer-managed key and alias.
4. `artifacts`: private, versioned, SSE-KMS S3 bucket.
5. `postgres configuration/subnet group/instance`: parameter group, private subnet group, RDS PostgreSQL 18.6.
6. `secrets`: empty Oracle source secret container; RDS manages target master credentials.
7. `iam`: EC2 SSM role; DMS VPC and CloudWatch roles; endpoint secret access role; Schema Conversion S3 role.
8. `tunnel gateway`: AL2023 EC2, EIP, fixed private IP and dedicated restricted SSH account.
9. `dms`: private replication subnet group/instance; optional endpoint and stopped task resources.
10. `schema conversion`: optional serverless instance profile, data providers and migration project; requires a separate Oracle metadata account and secret.
11. `monitoring`: SNS topic, optional email subscription, and CloudWatch alarms for DMS, RDS and the tunnel gateway.

`module.dms` depends on `module.iam`, and the DMS task is only created after endpoint resources are enabled. Schema Conversion is separately gated and uses the same DMS private networking and secret access role.
