# Oracle 19c to Amazon RDS for PostgreSQL — Terraform Infrastructure

This repository provisions and manages the AWS foundation for migrating Oracle 19c PDB `MIGPDB` to Amazon RDS for PostgreSQL 18.6. Terraform is mandatory for AWS infrastructure and IAM resources. AWS DMS Schema Conversion assesses/converts database objects; the DMS replication task moves table data and ongoing changes.

This project has its own Terraform state, S3 backend key, VPC, resource names, and PostgreSQL target. It is separate from the Oracle-to-RDS-for-Oracle project. Do not reuse or modify that project's state or resources.

> **Current status — November 25, 2026:** Infrastructure, endpoints, Schema Conversion project, target schema, premigration assessment, DMS replication task, and assessment IAM role are deployed/configured. Both endpoint connection tests succeeded. The selected premigration assessment passed 5/5 checks. The DMS task is `ready` and **has not been started**. Full Load, CDC execution, data reconciliation, and cutover have not begun.

## Current deployment status

| Component | Current state |
|---|---|
| AWS account / Region | `059317926607` / `us-east-1` |
| VPC | `vpc-05dcbe13f8a81bdd2` / `10.60.0.0/16` |
| RDS PostgreSQL | PostgreSQL `18.6`, `db.t3.medium`, Multi-AZ, database `oracle_migration` |
| RDS endpoint | `oracle-postgresql-migration-dev-postgres.cqngqgqyix25.us-east-1.rds.amazonaws.com:5432` |
| DMS replication instance | `oracle-postgresql-migration-dev-replication`; `dms.t3.medium`; engine `3.5.4`; `Available`; single-AZ; 50 GiB |
| DMS replication instance private IP | `10.60.11.70` |
| DMS subnet group | `oracle-postgresql-migration-dev-dms-private-subnets` |
| DMS source endpoint | `oracle-postgresql-migration-dev-oracle-source`; connection test `successful` |
| DMS target endpoint | `oracle-postgresql-migration-dev-postgres-target`; connection test `successful` |
| DMS Schema Conversion project | `oracle-postgresql-migration-dev-oracle-pg-sc`; created; four schemas assessed/converted |
| DMS task | `oracle-postgresql-migration-dev-full-load-cdc`; created; `ready`; not started |
| DMS task ARN | `arn:aws:dms:us-east-1:059317926607:task:MIDUXT5YWVC6XGGBQSLRCVAGSM` |
| Schema Conversion flag | `enable_schema_conversion_project=true` |
| DMS task flag | `create_dms_task=true`; `start_replication_task=false` |
| DMS endpoints flag | `create_dms_endpoints=true` |
| Artifact bucket | `orapgmig-dev-059317926607-us-east-1-artifacts`; SSE-S3 (`AES256`) |
| Reverse SSH gateway | EC2 `i-05924235a00ca097e`; public IP `18.207.5.67`; private IP `10.60.1.10`; listener TCP `11521` |
| DMS premigration assessment | `oracle-postgresql-migration-dev-pma-01`; 5/5 selected checks passed; 0 failed; 0 warnings |

## Latest Terraform changes

### DMS replication task — module `11_dms`

- `create_dms_task=true` in the development environment.
- Task identifier: `oracle-postgresql-migration-dev-full-load-cdc`.
- Migration type: `full-load-and-cdc`.
- `start_replication_task=false`; the task is created but deliberately not auto-started.
- Target table preparation: `DO_NOTHING` because the PostgreSQL schema and tables were deployed before the data load.
- `MaxFullLoadSubTasks=2`; transaction consistency timeout `600`; commit rate `10000`.
- CloudWatch task logging enabled.
- Table mappings contain four source-schema selection rules (`COMMON`, `FINANCE`, `GRANTS`, `PROCUREMENT`) and 12 lowercase transformations covering schema, table and column names (16 rules total).
- Target names are lowercase to match the deployed PostgreSQL schemas/tables.

The task was applied using a targeted plan that showed `1 added, 0 changed, 0 destroyed`. A prior full plan showed an unrelated in-place Schema Conversion project diff; the task deployment was isolated with a targeted plan. Always generate and review a fresh full plan before future applies; do not reuse saved plans.

### Premigration assessment IAM — module `9_iam`

A dedicated role `oracle-postgresql-migration-dev-dms-assessment-s3-role` and scoped inline policy were added. The role trusts `dms.amazonaws.com` and grants the assessment service access to the project artifacts bucket for bucket listing/location and assessment object read/write/delete/tagging. Module outputs expose the role ARN and name. The role and policy were deployed with a targeted plan: `2 added, 0 changed, 0 destroyed`.

### Oracle source readiness changes

- Oracle Binary Reader endpoint attributes: `useLogMinerReader=N;useBfile=Y`.
- DMS premigration assessment passed all five selected checks after DMS source-user permissions were completed.
- `DMS_USER` was granted `SELECT` on `DBA_SEGMENTS`, `V_$TABLESPACE`, `DBA_TAB_SUBPARTITIONS`, and `DBA_EXTENTS`. Keep the account least-privileged; do not grant DBA.
- Explicit `PRIMARY KEY LOGGING ALWAYS` groups are present for all 12 in-scope source tables.
- Oracle FRA limit increased from 10 GB to 20 GB. Preserve archived redo required by CDC; do not allow RMAN cleanup to delete logs before DMS consumes them.

### PostgreSQL target readiness

- Database: `oracle_migration`; engine: PostgreSQL 18.6.
- Deployed inventory: 4 schemas, 12 tables, 11 sequences, 29 indexes, 244 constraints.
- `dms_user` has `USAGE` on `common`, `finance`, `grants`, and `procurement`; `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on all 12 target tables.
- All 12 target tables were verified empty immediately before the planned Full Load.
- DMS target preparation is `DO_NOTHING`; DMS will use the pre-created objects.

## Architecture

- Region `us-east-1`; VPC `10.60.0.0/16`.
- Public subnets `10.60.1.0/24` (`us-east-1a`) and `10.60.2.0/24` (`us-east-1b`).
- Private subnets `10.60.11.0/24` (`us-east-1a`) and `10.60.12.0/24` (`us-east-1b`).
- Internet Gateway, public and per-AZ private route tables, S3 gateway endpoint; NAT Gateway disabled.
- Secrets Manager interface endpoint with private DNS.
- Public Amazon Linux 2023 EC2 reverse-tunnel gateway with Elastic IP, SSM instance profile, restricted `oracle-tunnel` account, private IP `10.60.1.10`.
- Oracle RHEL VM initiates the SSH reverse tunnel. DMS connects to `10.60.1.10:11521`; the tunnel forwards to Oracle listener `10.0.2.15:1521` from the RHEL VM.
- Private RDS PostgreSQL 18.6, `db.t3.medium`, 30 GiB gp3 storage, 100 GiB autoscaling ceiling, Multi-AZ, seven-day automated backups, deletion protection, RDS-managed master credentials.
- Private DMS replication instance, `dms.t3.medium`, 50 GiB storage, single-AZ.
- DMS Oracle source endpoint uses Secrets Manager credentials and Binary Reader. PostgreSQL target endpoint uses SSL.
- Customer-managed KMS key, versioned S3 artifacts bucket, IAM service roles, CloudWatch alarms and encrypted SNS notifications.

### Tunnel security boundary

The Oracle VM-to-EC2 gateway SSH session is encrypted. DMS-to-gateway traffic is a private VPC TCP connection to the reverse-forwarding listener; it is not end-to-end Oracle TCPS from DMS to the database listener. For a permanent enterprise design, prefer Site-to-Site VPN/Direct Connect and/or configure Oracle TCPS with DMS certificate validation.

The tunnel gateway security group allows SSH only from the Oracle VM's observed public egress address (`/32` at deployment). Reconfirm this address before using the tunnel because public egress IPs can change. Listener port `11521` is allowed only from the DMS security group.

### Security-group egress note

The DMS security group has an all-protocol outbound rule to `0.0.0.0/0`, following AWS DMS networking guidance. The replication instance remains in private subnets and NAT is disabled; actual reachability is also constrained by VPC routes and available VPC endpoints. Reassess this rule against AWS DMS requirements before tightening it.

## Repository layout

```text
terraform/
├── bootstrap/                         # Separate S3 state-bucket bootstrap root
├── environments/
│   └── dev/                            # Main development root module
│       ├── backend.hcl                 # Local backend settings; do not commit
│       ├── backend.hcl.example         # Backend configuration template
│       ├── .terraform.lock.hcl         # Provider selections; commit
│       ├── versions.tf
│       ├── provider.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars            # Local values; do not commit
├── modules/
│   ├── 1_networking/
│   ├── 2_security/
│   ├── 3_kms/
│   ├── 4_s3/
│   ├── 5_postgresql_rds_config/
│   ├── 6_postgresql_rds_subnet_group/
│   ├── 7_postgresql_rds_instance/
│   ├── 8_secrets/
│   ├── 9_iam/                          # DMS assessment S3 role/policy
│   ├── 10_ec2_tunnel_gateway/
│   ├── 11_dms/                         # Endpoints, task and table mappings
│   ├── 12_schema_conversion/
│   └── 13_monitoring/
├── scripts/
└── docs/
```

The development root declares an empty S3 backend in `versions.tf`. Backend values are supplied through local `backend.hcl` using `terraform init -backend-config=backend.hcl`. A separate `backend.tf` is not required.

## Terraform state and tooling

- State bucket: `oracle-postgresql-migration-tfstate-059317926607-us-east-1`.
- Main development state key: `oracle-postgresql-migration/dev/terraform.tfstate`.
- State Region: `us-east-1`.
- Backend uses S3 native lockfiles (`use_lockfile=true`), requiring Terraform 1.10 or later.
- Bootstrap root state is local and separate from the main development state.
- Recorded local tooling: Terraform `1.15.3`; AWS provider `6.73.0`; AWS Cloud Control provider `1.110.0`.
- Retain `.terraform.lock.hcl` in version control.
- Artifacts bucket default encryption is SSE-S3 (`AES256`). This configuration was observed to allow Schema Conversion project creation after a controlled isolation test; the exact underlying authorization failure mechanism was not independently proven. The customer-managed KMS key remains deployed for other resources. Do not revert the bucket to SSE-KMS without a separate controlled test and review.

## Configuration and feature flags

| Setting | Current value |
|---|---|
| AWS Region | `us-east-1` |
| VPC CIDR | `10.60.0.0/16` |
| Tunnel gateway private IP | `10.60.1.10` |
| Reverse-tunnel listener | TCP `11521` |
| Oracle listener | `10.0.2.15:1521` on source VM |
| Oracle PDB service | `migpdb` |
| PostgreSQL | `18.6`, `db.t3.medium`, Multi-AZ |
| PostgreSQL database | `oracle_migration` |
| DMS replication | `dms.t3.medium`, 50 GiB, single-AZ |
| NAT Gateway | Disabled |
| DMS endpoints | Enabled; deployed; connection tests successful |
| DMS task | Enabled; created; ready; not started |
| Schema Conversion project | Enabled; created; four schemas assessed/converted |

## Deployment and operating sequence

Run Terraform commands from `terraform/environments/dev`.

### 1. Initialize and validate

```bash
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
```

### 2. Create and review a fresh plan

```bash
terraform plan -var-file=terraform.tfvars -out=review.tfplan
terraform show review.tfplan
```

Review all additions, updates, replacements and destroys. Do not reuse a saved plan from an earlier infrastructure change.

### 3. Apply only the reviewed plan

```bash
terraform apply review.tfplan
```

### 4. Inspect outputs and state

```bash
terraform output
terraform state list
```

Verify AWS resources in the console or with the relevant AWS CLI describe commands. Do not print secret values.

## Oracle source and migration notes

- Source: Oracle 19c Enterprise Edition on RHEL 8.10, CDB `MIGCDB`, PDB `MIGPDB`.
- Source VM: 2 vCPU and 4 GiB RAM.
- Application schemas: `COMMON`, `FINANCE`, `GRANTS`, `PROCUREMENT`.
- Source baseline: 12 application tables and approximately 3.1 million rows; reconcile the historical 12-row difference (`3,096,217` versus `3,096,205`) during validation.
- `DMS_USER` is a dedicated local `MIGPDB` account with specific grants and no DBA role. It has `CREATE ANY DIRECTORY` for DMS-managed FRA directory objects. Protect the credential, rotate it after migration, and retire the account when no longer needed.
- Binary Reader requires access to actual archived redo files in the Oracle FRA. RMAN backup pieces alone are not a substitute for source archive files. Monitor FRA free space and preserve archive logs until DMS has consumed them.
- Schema Conversion uses a separate Oracle metadata account and secret. Do not reuse `DMS_USER`.

## Current migration progress and next steps

### Completed

1. Terraform AWS foundation and RDS PostgreSQL 18.6 target deployed.
2. DMS replication instance and both endpoints deployed; both endpoint tests successful.
3. DMS Schema Conversion project created; four schemas assessed/converted.
4. Reviewed target DDL deployed; 4 schemas, 12 tables, 11 sequences, 29 indexes and 244 constraints verified.
5. DMS premigration assessment completed: 5/5 selected checks passed, 0 failed, 0 warnings.
6. Oracle DMS source-user grants completed; all 12 source tables show `PRIMARY KEY LOGGING ALWAYS`; FRA set to 20 GB.
7. PostgreSQL DMS target privileges verified; all 12 target tables empty before initial load.
8. Terraform DMS task and assessment IAM role deployed.

### Current task state

The DMS task `oracle-postgresql-migration-dev-full-load-cdc` is `ready`, migration type `full-load-and-cdc`, Stop Reason `NORMAL`. It has not been started. Full Load, CDC execution, data validation, reconciliation and cutover remain pending.

### Start command — do not execute during documentation-only work

After explicit operator approval, run from Git Bash:

```bash
aws dms start-replication-task \
  --replication-task-arn arn:aws:dms:us-east-1:059317926607:task:MIDUXT5YWVC6XGGBQSLRCVAGSM \
  --start-replication-task-type start-replication \
  --region us-east-1
```

This begins Full Load followed by ongoing CDC; it is not production cutover. After starting, verify the task transitions to `running`, monitor table-level load state, rows loaded, errors and CloudWatch logs, then monitor CDC latency. Maintain archive-log retention while CDC is active.

### After Full Load

1. Reconcile source and target row counts, including the known historical 12-row discrepancy.
2. Validate aggregates, relationships, constraints, representative LOB values, sequences and application behavior.
3. Monitor CDC latency and confirm the target has caught up before cutover planning.
4. Rehearse cutover and rollback; obtain explicit approval before production traffic is redirected.

## Operational cost and security notes

- Main cost drivers include Multi-AZ RDS, DMS replication instance hours, EC2/EBS, Elastic IP/public IPv4 charges, the Secrets Manager interface endpoint, KMS, S3, CloudWatch and SNS. NAT Gateway charges are avoided in the current configuration.
- Consider stopping/removing DMS compute only after reviewing active CDC dependencies and archive retention.
- `dms-vpc-role` and `dms-cloudwatch-logs-role` are account-global role names. Do not duplicate or replace them blindly in other projects.
- The reverse SSH design encrypts source-to-gateway traffic only. DMS-to-gateway is private VPC TCP, not Oracle TCPS.
- Restrict access to the remote state bucket. Terraform state and saved plans can contain sensitive infrastructure metadata.

## Git commit safety checklist

Before committing Terraform files:

- Include Terraform `.tf` source, safe `.tfvars.example` files, `backend.hcl.example`, scripts, documentation and `.terraform.lock.hcl`.
- Exclude `terraform.tfvars`, `backend.hcl`, `*.tfstate`, `*.tfstate.*`, `*.tfplan`, `*.plan`, `.terraform/`, secret JSON, credentials, private keys and local logs.
- Review `git status --short` and inspect staged changes before committing.
- Do not use `git add -A` until ignore rules and the staged file list have been checked.

Example `.gitignore` entries:

```gitignore
**/.terraform/*
**/terraform.tfstate
**/terraform.tfstate.*
**/*.tfplan
**/*.plan
**/terraform.tfvars
**/terraform.tfvars.*
**/backend.hcl
**/secret*.json
**/*.pem
**/*_rsa
**/*_ed25519
```

---

**Last updated: November 25, 2026**
