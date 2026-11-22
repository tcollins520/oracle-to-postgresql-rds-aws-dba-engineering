# Oracle 19c to Amazon RDS for PostgreSQL — Terraform Infrastructure

This is a separate Terraform project and state for migrating the on-premises Oracle 19c PDB `MIGPDB` to Amazon RDS for PostgreSQL 18.6 using AWS DMS Full Load + CDC. It adapts selected networking, KMS, S3, RDS, and IAM patterns from the separate Oracle-to-RDS-Oracle project. It does not reuse that project's Terraform state or resources.

> **Deployment status — November 22, 2026:** Terraform initialization and validation have succeeded locally. The latest reviewed plan contains **66 resources to add, 0 to change, and 0 to destroy**. The user approved the saved plan and `terraform apply "dev.tfplan"` is currently running. The final apply result and post-deployment AWS verification are pending; update this section when the command completes.

## Important separation and safety

- Leave the previous Oracle-to-RDS-Oracle project, its Terraform state, saved plans, variables, and AWS resources untouched.
- This project uses its own VPC CIDR (`10.60.0.0/16`), state bucket, S3 backend key, resource names, and PostgreSQL database.
- Terraform creates Secrets Manager secret containers. Secret values and database passwords are populated outside Terraform.
- The initial deployment keeps DMS source/target endpoints, the DMS replication task, and the Schema Conversion project disabled. No migration starts during the infrastructure foundation deployment.
- Review every saved Terraform plan and obtain explicit approval before applying it. Do not run a second apply while the current apply is still running.
- Never commit state files, saved plan files, local `.tfvars`, `backend.hcl`, secret JSON, passwords, access keys, or private SSH keys.

## Architecture

- AWS Region: `us-east-1`.
- New VPC: `10.60.0.0/16`.
- Public subnets: `10.60.1.0/24` in `us-east-1a` and `10.60.2.0/24` in `us-east-1b`.
- Private subnets: `10.60.11.0/24` in `us-east-1a` and `10.60.12.0/24` in `us-east-1b`.
- Internet Gateway, public and per-AZ private route tables, and an S3 gateway endpoint. NAT Gateway is disabled by default.
- Secrets Manager interface endpoint with private DNS. DMS endpoint connection attributes include `secretsManagerEndpointOverride` so DMS can use the private endpoint for credential retrieval.
- Public Amazon Linux 2023 EC2 reverse-tunnel gateway with Elastic IP, SSM instance profile, restricted `oracle-tunnel` account, and private IP `10.60.1.10`.
- Oracle RHEL VM initiates the SSH reverse tunnel. DMS connects to `10.60.1.10:11521`; the tunnel forwards to the Oracle listener at `10.0.2.15:1521` from the RHEL VM.
- Private Amazon RDS for PostgreSQL 18.6, `db.t3.medium`, 30 GiB gp3 storage, 100 GiB autoscaling ceiling, Multi-AZ, seven-day automated backups, deletion protection, and RDS-managed master credentials.
- Private AWS DMS replication instance, `dms.t3.medium`, 50 GiB replication storage, and Multi-AZ disabled for initial development cost control.
- DMS source and target endpoints use Secrets Manager credentials. The Oracle source is configured for Binary Reader (`useLogMinerReader=N;useBfile=Y`). The PostgreSQL target endpoint requires SSL.
- The Full Load + CDC task uses `TargetTablePrepMode=DO_NOTHING`, two full-load subtasks, and `start_replication_task=false`.
- Optional AWS DMS Schema Conversion is a separate schema-conversion workflow using the AWS Cloud Control (`awscc`) provider. It does not migrate table data.
- Customer-managed KMS key, private/versioned/SSE-KMS S3 artifact bucket, CloudWatch alarms, and encrypted SNS notifications.

### Tunnel security boundary

The Oracle VM-to-EC2 gateway SSH session is encrypted. DMS-to-gateway traffic is a private VPC TCP connection to the reverse-forwarding listener; it is not end-to-end Oracle TCPS from DMS to the database listener. For a permanent enterprise design, prefer Site-to-Site VPN/Direct Connect and/or configure Oracle TCPS with DMS certificate validation.

The tunnel gateway security group allows SSH only from the Oracle VM's observed public egress address (`<SOURCE_PUBLIC_IP>/32` at the time of the initial plan). Reconfirm this address before using the tunnel because residential/public egress IPs can change. The tunnel listener port `11521` is allowed only from the DMS security group.

### Security-group egress note

The DMS security group currently has one all-protocol outbound rule to `0.0.0.0/0`, following AWS DMS networking guidance. This is broader at the security-group layer than the initial four destination-specific rules. The DMS replication instance remains in private subnets, and NAT is disabled; actual reachability is also constrained by VPC routes and the available VPC endpoints. Reassess this rule against AWS DMS requirements before tightening it. The tunnel gateway retains HTTPS egress for SSM/package access and PostgreSQL egress to the RDS security group.

## Repository layout

Current local project directory:

`<LOCAL_PATH>/Documents/oracle-to-postgresql-rds-aws-migration-etl/terraform`

```text
terraform/
├── bootstrap/                          # Separate S3 state-bucket bootstrap root
├── environments/
│   └── dev/                             # Main development root module
│       ├── backend.hcl                  # Local backend settings; do not commit
│       ├── backend.hcl.example          # Backend configuration template
│       ├── .terraform.lock.hcl           # Provider selections; retain in version control
│       ├── versions.tf                   # Includes the empty S3 backend declaration
│       ├── provider.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars             # Local values; do not commit
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

The main development root declares an empty S3 backend in `versions.tf`; the backend values are supplied using `backend.hcl` with `terraform init -backend-config=backend.hcl`. A separate `backend.tf` file is not required and is not part of the current layout.

## Terraform state and local tooling

- State bucket: `oracle-postgresql-migration-tfstate-<AWS_ACCOUNT_ID>-us-east-1`.
- Main development state key: `oracle-postgresql-migration/dev/terraform.tfstate`.
- State Region: `us-east-1`.
- Backend uses S3 native lockfiles (`use_lockfile = true`), requiring Terraform 1.10 or later.
- The bootstrap root's state remains local and separate from the main development state.
- Local tool versions recorded during setup: Terraform `1.16.3`, AWS CLI `2.37.0`, AWS provider `6.73.0`, and AWS Cloud Control provider `1.110.0` selected under the configured `~> 1.98` constraint. `.terraform.lock.hcl` was generated during initialization and should be retained in version control when the Git repository is created.

The bootstrap state bucket was created and verified with versioning enabled, SSE-S3 (`AES256`) encryption, all four S3 public-access-block settings enabled, and `BucketOwnerEnforced` ownership controls. Its bucket policy denies insecure transport.

## Configuration defaults and preflight notes

| Component | Current setting |
|---|---|
| AWS Region | `us-east-1` |
| VPC CIDR | `10.60.0.0/16` |
| Public subnets | `10.60.1.0/24`, `10.60.2.0/24` |
| Private subnets | `10.60.11.0/24`, `10.60.12.0/24` |
| Tunnel gateway private IP | `10.60.1.10` |
| Reverse-tunnel listener | TCP `11521` |
| Oracle source listener | `10.0.2.15:1521` from the source VM; DMS connects via gateway tunnel |
| PostgreSQL | PostgreSQL `18.6`, `db.t3.medium`, Multi-AZ |
| PostgreSQL storage | 30 GiB gp3; autoscaling maximum 100 GiB |
| PostgreSQL database | `oracle_migration` |
| DMS replication | `dms.t3.medium`, 50 GiB, single-AZ |
| NAT Gateway | Disabled |
| DMS endpoints | Disabled (`create_dms_endpoints=false`) |
| DMS task | Disabled (`create_dms_task=false`) |
| Schema Conversion project | Disabled (`enable_schema_conversion_project=false`) |

The VPC and subnet CIDRs were compared with the existing AWS VPC CIDRs known during preflight and were non-overlapping. Recheck connected/on-premises/VPN networks before extending connectivity.

The RDS orderability check confirmed PostgreSQL 18.6 with `db.t3.medium` and Multi-AZ capability in the selected Region. DMS `dms.t3.medium` was also listed as orderable during preflight. Recheck service quotas and orderability if the Region, class, or engine version changes.

## Deployment sequence and current progress

### 0. Preflight AWS account, networking, roles, and orderability

The following read-only checks were run during preflight:

```bash
aws sts get-caller-identity --region us-east-1
aws ec2 describe-vpcs --region us-east-1 --query 'Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,Default:IsDefault}' --output table
aws ec2 describe-availability-zones --region us-east-1 --filters Name=state,Values=available --query 'AvailabilityZones[].ZoneName' --output table
aws iam get-role --role-name dms-vpc-role --query Role.Arn --output text
aws iam get-role --role-name dms-cloudwatch-logs-role --query Role.Arn --output text
aws rds describe-orderable-db-instance-options --engine postgres --engine-version 18.6 --db-instance-class db.t3.medium --region us-east-1 --query 'OrderableDBInstanceOptions[].{Class:DBInstanceClass,EngineVersion:EngineVersion,MultiAZCapable:MultiAZCapable,Storage:StorageType,AZs:AvailabilityZones[].Name}' --output table
aws dms describe-orderable-replication-instances --region us-east-1 --query "OrderableReplicationInstances[?ReplicationInstanceClass=='dms.t3.medium'].ReplicationInstanceClass" --output table
```

Both account-global DMS roles (`dms-vpc-role` and `dms-cloudwatch-logs-role`) were absent during the preflight check, so their Terraform management flags are set to `true`. Do not create or replace these account-level roles in another project without reviewing ownership and trust policies.

The Oracle RHEL VM reported public egress IP `<SOURCE_PUBLIC_IP>` during setup. Reconfirm with:

```bash
curl -4 -sS https://checkip.amazonaws.com
```

A dedicated Ed25519 key was generated **inside the Oracle RHEL VM** at `/home/oracleadmin/.ssh/oracle_dms_tunnel`. The corresponding public key was supplied to local `terraform.tfvars`; the private key remains on the RHEL VM and must not be copied to the Mac or committed.

The user also generated a separate Mac key during setup. That is not the key configured in the gateway's Terraform user data; the configured public key is the one generated inside `oracle19c-source`.

### 1. Bootstrap the remote Terraform state bucket

Completed. The bucket was created using the separate `bootstrap/` Terraform root. Its local state and plan files must remain secure and must not be committed.

### 2. Configure the development backend and variables

Completed. The development root uses:

```hcl
bucket       = "oracle-postgresql-migration-tfstate-<AWS_ACCOUNT_ID>-us-east-1"
key          = "oracle-postgresql-migration/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

The actual `terraform.tfvars` includes the Oracle source CIDR `<SOURCE_PUBLIC_IP>/32` and the public SSH key generated inside RHEL. Keep the file local and excluded from Git.

### 3. Initialize, format, validate, and plan

Completed locally:

- `terraform init -backend-config=backend.hcl` successfully initialized the S3 backend and all 13 modules.
- AWS and AWSCC provider plugins installed successfully; `.terraform.lock.hcl` was created.
- The three incorrect PostgreSQL module source paths in `environments/dev/main.tf` were corrected to match the actual module directory names.
- `terraform fmt` and `terraform validate` completed successfully after the module and monitoring updates.
- AWS region data references were changed from deprecated `.name` to `.region`; the latest supplied plan output did not show the previous deprecation warnings.

Latest reviewed command:

```bash
terraform plan -out=dev.tfplan
```

Latest reviewed summary:

```text
Plan: 66 to add, 0 to change, 0 to destroy.
```

The saved plan is `environments/dev/dev.tfplan`. The plan contains the VPC and subnets, route tables and endpoints, PostgreSQL RDS and parameter/subnet groups, DMS replication instance and subnet group, IAM roles/policies, KMS, S3 artifacts bucket, Secrets Manager containers, security groups, EC2 tunnel gateway and Elastic IP, CloudWatch alarms, and SNS topic/policy.

The plan intentionally does **not** create DMS source/target endpoints, a DMS replication task, or a Schema Conversion project because their feature flags remain `false`.

### 4. Initial infrastructure apply — in progress

The user explicitly approved the reviewed saved plan and started:

```bash
terraform apply "dev.tfplan"
```

**Status at last README update:** apply is running. Do not start another apply while it is active. When it completes, record the exact `Apply complete!` resource counts, capture the Terraform outputs, and verify the created AWS resources. If apply fails or partially completes, inspect the error and Terraform state before retrying.

## Initial deployment components

### Networking

- VPC `10.60.0.0/16`, public/private subnets in `us-east-1a` and `us-east-1b`.
- Internet Gateway and public route table.
- Separate private route tables per AZ.
- S3 gateway endpoint associated with the private routing design.
- Secrets Manager interface endpoint in private subnets with private DNS.
- NAT Gateway disabled.

### Security groups

- Tunnel gateway SSH ingress: Oracle source egress `/32`, TCP 22.
- Tunnel listener ingress: DMS security group only, TCP 11521.
- PostgreSQL ingress: DMS and tunnel gateway security groups only, TCP 5432.
- Secrets Manager endpoint ingress: DMS security group only, TCP 443.
- Tunnel gateway egress: TCP 443 for SSM/package repositories and TCP 5432 to PostgreSQL.
- DMS egress: all protocols to `0.0.0.0/0`, with actual connectivity also determined by private subnet routes and VPC endpoints.

### RDS PostgreSQL

- Engine/version: PostgreSQL 18.6.
- Instance class: `db.t3.medium`.
- Multi-AZ: enabled.
- Storage: 30 GiB gp3, autoscaling maximum 100 GiB.
- Encryption: customer-managed KMS key.
- Automated backups: seven days.
- Deletion protection: enabled.
- Public accessibility: disabled.
- Master credentials: RDS-managed Secrets Manager secret.
- Parameter group: PostgreSQL 18 family, `rds.force_ssl=1`.

### DMS

- Replication instance: `dms.t3.medium`, 50 GiB, private, single-AZ.
- Replication subnet group spans the two private subnets.
- Oracle source endpoint: disabled initially; planned for PDB service `migpdb` via gateway tunnel, Binary Reader, and Secrets Manager.
- PostgreSQL target endpoint: disabled initially; planned with SSL mode `require` and a least-privilege DMS target login.
- Full Load + CDC task: disabled initially, `DO_NOTHING`, two full-load subtasks, and not started automatically.

### IAM and encryption

- EC2 gateway role uses `AmazonSSMManagedInstanceCore`.
- Account-level DMS VPC and CloudWatch logging roles are created only because preflight found them absent.
- DMS endpoint secret role has access to only the Oracle DMS and PostgreSQL DMS endpoint secrets and the project KMS key.
- Schema Conversion uses separate secrets and S3 roles with service-specific trust policies.
- Schema Conversion S3 policy includes bucket listing/location/versioning and scoped artifact object access. Its KMS use is restricted through S3 service access.
- Customer-managed KMS key rotation is enabled; key deletion window is 30 days; Terraform `prevent_destroy` is enabled.
- S3 artifact bucket has BucketOwnerEnforced ownership, all public access blocks, versioning, SSE-KMS using the project key, bucket keys, and a policy denying insecure transport. Terraform `prevent_destroy` is enabled.

### Monitoring

- Encrypted SNS topic uses the project customer-managed KMS key.
- SNS topic policy allows CloudWatch alarm publishing from this account and project alarm-name scope.
- PostgreSQL alarms: CPU above 80% for three five-minute periods; free storage below 5 GiB.
- DMS alarms: CPU above 80% for three five-minute periods; free storage below 10 GiB.
- EC2 tunnel gateway status-check alarm.
- Email subscription is optional and currently disabled because `notification_email` is empty.

## Post-deployment sequence

Do not begin these steps until the infrastructure apply succeeds and the outputs/resources have been verified.

### 1. Verify outputs and AWS resources

Run from `environments/dev`:

```bash
terraform output
terraform state list
```

Verify in AWS the VPC, subnets, route tables, VPC endpoints, security groups, RDS instance, DMS replication instance, EC2 gateway/EIP, KMS key, S3 artifact bucket, Secrets Manager containers, IAM roles, CloudWatch alarms, and SNS topic. Confirm no DMS endpoints/task or Schema Conversion project were created yet.

### 2. Populate endpoint credentials outside Terraform state

Terraform creates the Secrets Manager containers only. It does not create secret versions or put database passwords into Terraform state.

The Oracle DMS secret must include `username`, `password`, `host` (the gateway private IP), and `port` (`11521`). Use `DMS_USER`, not the Schema Conversion metadata user.

The PostgreSQL DMS target secret must use a separate least-privilege `dms_target` account and include `engine=postgres`, `username`, `password`, `host`, `port=5432`, and `dbname`. Do not use the RDS master account for DMS replication.

The Schema Conversion Oracle metadata secret is separate from the DMS source secret. Schema Conversion can use the RDS-managed master secret for target metadata assessment, but the DMS replication endpoint must use the least-privilege `dms_target` secret.

Use the repository scripts where present:

```bash
../../scripts/populate-oracle-source-secret.ps1
../../scripts/populate-postgres-target-secret.ps1
../../scripts/populate-schema-conversion-oracle-secret.ps1
```

These `.ps1` helper scripts are PowerShell scripts; run them in a compatible PowerShell environment. Do not paste passwords into command history, Terraform source, or `.tfvars`.

### 3. Establish and test the reverse SSH tunnel

The RHEL source VM initiates the reverse tunnel after the gateway public IP is available from Terraform output. The forwarding pattern is:

```bash
ssh -NT \
  -i /home/oracleadmin/.ssh/oracle_dms_tunnel \
  -o IdentitiesOnly=yes \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o StrictHostKeyChecking=accept-new \
  -R 10.60.1.10:11521:10.0.2.15:1521 \
  oracle-tunnel@<GATEWAY_ELASTIC_IP>
```

Use the actual Terraform output values. Validate the tunnel interactively before configuring automatic restart. On the EC2 gateway, connect using SSM and inspect the listener:

```bash
sudo ss -lntp | grep ':11521'
```

The source VM initiates SSH; home-router port forwarding is not required. Test Oracle listener reachability through the tunnel from the AWS network before enabling DMS endpoints.

### 4. Prepare Schema Conversion and target DDL

For online Oracle Schema Conversion, create a separate PDB metadata account and grant the privileges required by the currently supported AWS Schema Conversion workflow. The README's planned privilege set is `CONNECT`, `SELECT_CATALOG_ROLE`, `SELECT ANY DICTIONARY`, and `SELECT ON SYS.ARGUMENT$`; verify against current AWS documentation before granting. Do not reuse `DMS_USER` as the metadata account.

Only after the metadata account/secret, tunnel connectivity, and role access are verified should `enable_schema_conversion_project=true` be set. Review a new Terraform plan before applying the Schema Conversion resources.

Run the assessment, review unsupported Oracle objects and data types, export the converted PostgreSQL DDL, and apply only reviewed DDL. Schema Conversion handles schema conversion; it does not migrate table data.

### 5. Enable DMS endpoints and Full Load + CDC separately

After the Oracle tunnel is tested, populate the Oracle endpoint secret with `DMS_USER`. Create and grant the least-privilege PostgreSQL `dms_target` login after target DDL has been applied, then populate its secret.

Set `create_dms_endpoints=true` only after both secrets and network paths are ready. Generate a fresh plan, review and apply it, then test both DMS endpoints.

Set `create_dms_task=true` only after endpoint tests, target schema, and table mappings are approved. Generate a fresh plan, review/apply it, then start the task only after explicit operational review. Monitor full-load progress, CDC latency, Oracle archive retention/FRA usage, target errors, and row-count/data reconciliation.

## Oracle source preparation and migration notes

- Source: Oracle 19c Enterprise Edition on RHEL 8.10, CDB `MIGCDB`, PDB `MIGPDB`.
- Source VM resources: 2 vCPU and 4 GiB RAM. Keep DMS full-load subtasks conservative at two until measured.
- Application schemas: `COMMON`, `FINANCE`, `GRANTS`, and `PROCUREMENT`.
- The source contains 12 application tables and approximately 3.1 million rows in the current baseline.
- `DMS_USER` is a dedicated local `MIGPDB` account with specific grants and no DBA role. Do not broaden it to DBA.
- CDB supplemental logging was enabled; PDB primary-key supplemental logging was enabled for `MIGPDB`; primary keys were validated on the 12 application tables.
- `DMS_USER` has `CREATE ANY DIRECTORY` for DMS-managed FRA directory objects. Protect this credential, rotate it after migration, and retire the account when no longer needed.
- Binary Reader requires access to the actual archived redo files in the Oracle FRA. RMAN backup pieces alone are not a substitute for source archive files. Recheck FRA free space and archive-log retention immediately before CDC; do not allow RMAN cleanup to remove logs before DMS has consumed them.
- Schema Conversion requires a separate Oracle metadata account; its provisioning and privilege verification remain future work.

## Operational cost and security notes

- Main cost drivers include Multi-AZ RDS, DMS replication instance hours, EC2/EBS, Elastic IP/public IPv4 charges, the Secrets Manager interface endpoint, KMS, S3, CloudWatch, and SNS. NAT Gateway charges are avoided in the current configuration.
- Consider stopping or removing DMS compute when it is not needed, but review operational dependencies and CDC retention before doing so.
- The DMS security group currently permits all outbound traffic at the security-group layer. The private route tables and absence of NAT limit general public Internet routing; VPC endpoints provide the planned private AWS service access. Revisit the broad egress rule against AWS DMS networking requirements before tightening.
- `dms-vpc-role` and `dms-cloudwatch-logs-role` are account-global role names. Do not duplicate or replace them blindly in other projects.
- The reverse SSH design encrypts source-to-gateway traffic only. DMS-to-gateway is private VPC TCP, not Oracle TCPS.
- State and plan files can contain sensitive infrastructure metadata. Restrict access to the remote state bucket and never commit `terraform.tfstate`, `*.tfplan`, `terraform.tfvars`, `backend.hcl`, secret JSON, passwords, or private keys.

## Current validation and deployment record

| Check | Status as of November 22, 2026 |
|---|---|
| Bootstrap state bucket | Created and security settings verified |
| Main S3 backend initialization | Successful |
| Module initialization | All 13 modules initialized |
| Provider installation | AWS `6.73.0`; AWSCC `1.110.0` |
| Terraform formatting | Completed for updated modules and root files |
| Terraform validation | Successful after latest code changes |
| AWS Region deprecation warnings | Corrected; absent from latest supplied plan output |
| Latest saved plan | `dev.tfplan` |
| Latest plan summary | 66 add, 0 change, 0 destroy |
| Initial infrastructure apply | **In progress; final result pending** |
| Post-apply AWS verification | Pending |

Update the deployment status and this table after the current `terraform apply "dev.tfplan"` command returns. Record the actual applied resource counts and verification results; do not infer success from the plan alone.
