# Oracle 19c to Amazon RDS for PostgreSQL — Terraform Infrastructure

This Terraform project provisions the AWS foundation for migrating the Oracle 19c PDB `MIGPDB` to Amazon RDS for PostgreSQL 18.6. AWS Database Migration Service (DMS) is used for endpoint connectivity and the planned Full Load + CDC migration. AWS DMS Schema Conversion is used to assess and convert database objects; it does **not** migrate table data.

This project has its own Terraform state, S3 backend key, VPC, resource names, and PostgreSQL target. It is separate from the Oracle-to-RDS-for-Oracle project. Do not reuse or modify that project's state or resources.

> **Current status — November 23, 2026:** Terraform foundation, RDS PostgreSQL target, DMS replication instance, reverse-tunnel gateway, and both DMS endpoints are deployed. Both DMS endpoint connection tests have succeeded. The DMS Schema Conversion project has also been created successfully. The replication instance is `Available`. Schema assessment and target application-schema deployment are the next work items. The DMS replication task has **not** been created or started; Full Load, CDC, data validation, and cutover have not begun.

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
| DMS Schema Conversion project | `oracle-postgresql-migration-dev-oracle-pg-sc`; created |
| DMS replication task | Not created; `create_dms_task=false` |
| Schema Conversion Terraform flag | Enabled; `enable_schema_conversion_project=true` |
| Artifact bucket | `orapgmig-dev-059317926607-us-east-1-artifacts`; default encryption SSE-S3 (`AES256`) |
| Reverse SSH gateway | EC2 `i-05924235a00ca097e`; public IP `18.207.5.67`; private IP `10.60.1.10`; listener TCP `11521` |

### Latest Terraform deployment

The most recent reviewed Terraform plan and apply for the Schema Conversion project completed successfully:

```text
Apply complete! Resources: 1 added, 1 changed, 0 destroyed.
```

The plan preserved both existing DMS endpoints. The Schema Conversion project ARN is:

```text
arn:aws:dms:us-east-1:059317926607:migration-project:OTVOMJ3UVJEJTMS2UAA6MTTTZQ
```

Earlier deployment milestones included the initial AWS foundation and a separate endpoint deployment (`2 added, 0 changed, 0 destroyed`). Do not reuse historical saved plans; create a fresh plan for every change.

## Important separation and safety

- Leave the separate Oracle-to-RDS-for-Oracle project, its state, saved plans, variables, and AWS resources untouched.
- This project uses VPC CIDR `10.60.0.0/16`, its own S3 state bucket and key, and database `oracle_migration`.
- Terraform creates Secrets Manager secret containers. Secret values and database passwords are populated outside Terraform.
- Never commit `terraform.tfvars`, `backend.hcl`, secret JSON, passwords, access keys, private SSH keys, Terraform state, saved plan files, or `.terraform/`.
- Retain `.terraform.lock.hcl` in version control.
- Review every Terraform plan before applying it. Never use `-lock=false` as a routine workaround for state-lock errors.
- Keep `create_dms_endpoints=true` to preserve the deployed endpoints. Setting it to `false` previously caused a plan to propose destroying them.
- Keep `create_dms_task=false` until schema assessment, target DDL, table mappings, premigration assessment, and CDC readiness are reviewed.
- Keep `enable_schema_conversion_project=true` because the Schema Conversion project is deployed.

## Architecture

- Region: `us-east-1`.
- VPC: `10.60.0.0/16`.
- Public subnets: `10.60.1.0/24` (`us-east-1a`) and `10.60.2.0/24` (`us-east-1b`).
- Private subnets: `10.60.11.0/24` (`us-east-1a`) and `10.60.12.0/24` (`us-east-1b`).
- Internet Gateway, public and per-AZ private route tables, and an S3 gateway endpoint. NAT Gateway is disabled.
- Secrets Manager interface endpoint with private DNS.
- Public Amazon Linux 2023 EC2 reverse-tunnel gateway with Elastic IP, SSM instance profile, restricted `oracle-tunnel` account, and private IP `10.60.1.10`.
- Oracle RHEL VM initiates the SSH reverse tunnel. DMS connects to `10.60.1.10:11521`; the tunnel forwards to Oracle listener `10.0.2.15:1521` from the RHEL VM.
- Private RDS PostgreSQL 18.6, `db.t3.medium`, 30 GiB gp3 storage, 100 GiB autoscaling ceiling, Multi-AZ, seven-day automated backups, deletion protection, and RDS-managed master credentials.
- Private DMS replication instance, `dms.t3.medium`, 50 GiB storage, single-AZ.
- DMS Oracle source endpoint uses Secrets Manager credentials and Binary Reader (`useLogMinerReader=N;useBfile=Y`). PostgreSQL target endpoint uses SSL.
- Planned Full Load + CDC task uses `TargetTablePrepMode=DO_NOTHING`, two full-load subtasks, and `start_replication_task=false`.
- Customer-managed KMS key, versioned S3 artifacts bucket, IAM service roles, CloudWatch alarms, and encrypted SNS notifications.

### Tunnel security boundary

The Oracle VM-to-EC2 gateway SSH session is encrypted. DMS-to-gateway traffic is a private VPC TCP connection to the reverse-forwarding listener; it is not end-to-end Oracle TCPS from DMS to the database listener. For a permanent enterprise design, prefer Site-to-Site VPN/Direct Connect and/or configure Oracle TCPS with DMS certificate validation.

The tunnel gateway security group allows SSH only from the Oracle VM's observed public egress address (`/32` at the time of deployment). Reconfirm this address before using the tunnel because public egress IPs can change. The tunnel listener port `11521` is allowed only from the DMS security group.

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
│   ├── 9_iam/
│   ├── 10_ec2_tunnel_gateway/
│   ├── 11_dms/
│   ├── 12_schema_conversion/
│   └── 13_monitoring/
├── scripts/
└── docs/
```

The development root declares an empty S3 backend in `versions.tf`. Backend values are supplied through the local `backend.hcl` file using `terraform init -backend-config=backend.hcl`. A separate `backend.tf` is not required.

## Terraform state and tooling

- State bucket: `oracle-postgresql-migration-tfstate-059317926607-us-east-1`.
- Main development state key: `oracle-postgresql-migration/dev/terraform.tfstate`.
- State Region: `us-east-1`.
- Backend uses S3 native lockfiles (`use_lockfile=true`), requiring Terraform 1.10 or later.
- Bootstrap root state is local and separate from the main development state.
- Recorded local tooling: Terraform `1.15.3`; AWS provider `6.73.0`; AWS Cloud Control provider `1.110.0`.
- Keep the provider lock file in version control.

The artifacts bucket was changed from SSE-KMS to SSE-S3 (`AES256`) for a controlled Schema Conversion project-creation isolation test. Project creation succeeded after the change. This is the successful configuration observed in this environment; the precise underlying AWS authorization failure mechanism was not independently proven. The customer-managed KMS key remains deployed for other project resources. Do not revert the artifacts bucket to SSE-KMS without a separate controlled test and review.

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
| DMS endpoints | Enabled; both deployed and connection tests successful |
| DMS task | Disabled; not created |
| Schema Conversion project | Enabled; created |

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

Review all additions, updates, replacements, and destroys. Do not reuse a saved plan from an earlier infrastructure change.

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
- Application schemas: `COMMON`, `FINANCE`, `GRANTS`, and `PROCUREMENT`.
- Current baseline: 12 application tables and approximately 3.1 million rows.
- `DMS_USER` is a dedicated local `MIGPDB` account with specific grants and no DBA role. Do not broaden it to DBA.
- CDB supplemental logging was enabled; PDB primary-key supplemental logging was enabled for `MIGPDB`; primary keys were validated on the 12 application tables.
- `DMS_USER` has `CREATE ANY DIRECTORY` for DMS-managed FRA directory objects. Protect this credential, rotate it after migration, and retire the account when no longer needed.
- Binary Reader requires access to actual archived redo files in the Oracle FRA. RMAN backup pieces alone are not a substitute for source archive files. Recheck FRA free space and archive-log retention immediately before CDC; do not allow RMAN cleanup to remove logs before DMS has consumed them.
- Schema Conversion uses a separate Oracle metadata account and secret. Do not reuse `DMS_USER`.

## Current migration progress and next steps

### Completed

1. Terraform foundation deployed.
2. RDS PostgreSQL 18.6 target deployed.
3. DMS replication instance deployed and verified `Available` in the AWS console.
4. Oracle reverse SSH tunnel/gateway path configured.
5. DMS Oracle source and PostgreSQL target endpoints created.
6. Both DMS endpoint connection tests returned `successful`.
7. PostgreSQL `dms_user` login created with initial database/schema permissions.
8. DMS Schema Conversion project created successfully through Terraform.

### Next: Schema Conversion assessment

1. Open AWS DMS in `us-east-1` and select `oracle-postgresql-migration-dev-oracle-pg-sc`.
2. Verify source and target metadata connectivity.
3. Assess Oracle schemas `COMMON`, `FINANCE`, `GRANTS`, and `PROCUREMENT`.
4. Export and review the assessment summary, complexity report, and action items.
5. Review Oracle data types, identifiers/case, LOBs, sequences, constraints, indexes, views, procedures, functions, triggers, and packages.
6. Remediate conversion issues and review generated PostgreSQL DDL.
7. Apply only reviewed DDL to RDS and validate the target application schemas.

### After schema conversion

1. Run the DMS premigration assessment.
2. Review table mappings, LOB handling, parallelism, error handling, and validation settings.
3. Confirm Oracle CDC prerequisites, supplemental logging, archive-log retention, and FRA capacity.
4. Keep `create_dms_task=false` until the target schema and migration design are approved.
5. Create the Full Load + CDC task through a separately reviewed Terraform plan.
6. Start the task only after operational review; monitor Full Load, CDC latency, errors, and archive retention.
7. Reconcile row counts, aggregates, relationships, LOB samples, sequences, and application behavior.
8. Reconcile the historical 12-row difference in the source count baseline.
9. Prepare and rehearse cutover and rollback. Cutover requires explicit approval.

## Operational cost and security notes

- Main cost drivers include Multi-AZ RDS, DMS replication instance hours, EC2/EBS, Elastic IP/public IPv4 charges, the Secrets Manager interface endpoint, KMS, S3, CloudWatch, and SNS. NAT Gateway charges are avoided in the current configuration.
- Consider stopping or removing DMS compute when it is not needed, but review operational dependencies and CDC retention first.
- `dms-vpc-role` and `dms-cloudwatch-logs-role` are account-global role names. Do not duplicate or replace them blindly in other projects.
- The reverse SSH design encrypts source-to-gateway traffic only. DMS-to-gateway is private VPC TCP, not Oracle TCPS.
- Restrict access to the remote state bucket. Terraform state and saved plans can contain sensitive infrastructure metadata.

## Git commit safety checklist

Before committing Terraform files:

- Include Terraform `.tf` source, safe `.tfvars.example` files, `backend.hcl.example`, scripts, documentation, and `.terraform.lock.hcl`.
- Exclude `terraform.tfvars`, `backend.hcl`, `*.tfstate`, `*.tfstate.*`, `*.tfplan`, `*.plan`, `.terraform/`, secret JSON, credentials, private keys, and local logs.
- Review `git status --short` and inspect staged changes before committing.
- Do not use `git add -A` until the ignore rules and staged file list have been checked.

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

**Last updated:** November 23, 2026
