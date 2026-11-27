# Oracle 19c to Amazon RDS for PostgreSQL Migration

A production-style cloud database migration engineering portfolio project demonstrating the assessment, conversion, migration, operation, validation, and modernization of an Oracle Database 19c Enterprise Edition environment to Amazon RDS for PostgreSQL 18.6 using AWS-native services and Terraform.

> **Project status — November 27, 2026:** AWS infrastructure, Oracle source connectivity, DMS endpoints, DMS Schema Conversion project, converted PostgreSQL target schema, and DMS Full Load + CDC execution are complete. All 12 in-scope table row counts reconcile exactly (3,096,217 rows total), and primary-key metrics match across all 12 tables. A controlled CDC test demonstrated INSERT, UPDATE, and DELETE application with zero errors. Automated all-column comparison across all 12 tables, sustained CDC validation, and cutover/rollback rehearsal remain outstanding. **Production cutover has not occurred.**

## Project objectives

- Engineer a realistic Oracle 19c source environment and capture its database, schema, data, and operational baseline.
- Provision and manage all AWS infrastructure through Terraform and infrastructure-as-code practices.
- Assess Oracle database objects and convert the in-scope schema for PostgreSQL compatibility.
- Migrate data using AWS Database Migration Service (AWS DMS) with a Full Load + Change Data Capture (CDC) approach.
- Operate and secure the PostgreSQL target using Amazon RDS capabilities and PostgreSQL DBA practices.
- Validate migrated data, database behavior, recoverability, performance, and operational readiness before cutover.
- Extend the platform with analytics, reporting, multi-source ingestion, and data warehouse engineering.

## Architecture overview

```text
+----------------------------------+
| On-premises / Virtualized Source  |
|                                  |
| Windows 11 Pro host              |
|   └── VirtualBox / Vagrant       |
|       └── RHEL 8.10              |
|           └── Oracle 19c EE      |
|               CDB: MIGCDB        |
|               PDB: MIGPDB        |
+----------------+-----------------+
                 |
                 | Oracle VM initiates reverse SSH tunnel
                 v
+----------------------------------+
| AWS us-east-1                    |
|                                  |
| VPC 10.60.0.0/16                 |
|                                  |
| EC2 reverse-tunnel gateway       |
| private listener :11521         |
|              |                   |
|              v                   |
| AWS DMS replication instance    |
|   ├── Oracle source endpoint    |
|   └── PostgreSQL target endpoint|
|              |                   |
|              v                   |
| Amazon RDS for PostgreSQL 18.6  |
| database: oracle_migration      |
| Multi-AZ                         |
+----------------------------------+

Separate supporting workstreams:
- AWS DMS Schema Conversion: Oracle metadata assessment and schema/code conversion
- Terraform: AWS infrastructure provisioning and lifecycle management
- Secrets Manager, IAM, KMS, S3, CloudWatch and SNS: security and operations
```

**Important distinction:** AWS DMS Schema Conversion assesses and converts database objects and code. The AWS DMS replication task performs table data migration and ongoing CDC. These are separate workstreams.

## Technology stack

| Area | Technologies |
|---|---|
| Source database | Oracle Database 19c Enterprise Edition |
| Source operating system | RHEL 8.10 |
| Source virtualization | Windows 11 Pro, VirtualBox, Vagrant |
| Target database | Amazon RDS for PostgreSQL 18.6 |
| Migration | AWS DMS Full Load + CDC |
| Schema assessment and conversion | AWS DMS Schema Conversion |
| Infrastructure as code | Terraform |
| Cloud platform | AWS, VPC, EC2, RDS, DMS, S3, IAM, KMS |
| Connectivity | SSH reverse tunnel, AWS Systems Manager port forwarding |
| Security and secrets | IAM, AWS Secrets Manager, KMS, TLS/SSL |
| Monitoring | Amazon CloudWatch, SNS |
| Database administration | Oracle SQL*Plus/RMAN, PostgreSQL SQL/pgAdmin |
| Future ingestion and orchestration | Apache NiFi 2.12, Apache Airflow |
| Source control | Git and GitHub |

## Project scope and baseline

### Oracle source

- Oracle Database 19c Enterprise Edition, RU 19.33.0.0.261020.
- Container database: `MIGCDB`.
- Pluggable database: `MIGPDB`.
- Operating system: RHEL 8.10.
- Application schemas: `COMMON`, `FINANCE`, `GRANTS`, and `PROCUREMENT`.
- Source inventory: 12 application tables, 11 sequences, 29 indexes, and 244 constraints.
- Approximate source data volume: 3.1 million rows.
- Fresh per-table reconciliation superseded the earlier 12-row aggregate count discrepancy: all 12 table counts now match exactly, totaling 3,096,217 rows. The original cause of the earlier aggregate discrepancy was not conclusively established.

### AWS target and migration components

- AWS Region: `us-east-1`.
- VPC CIDR: `10.60.0.0/16`.
- Target: Amazon RDS for PostgreSQL 18.6, `db.t3.medium`, Multi-AZ.
- Target database: `oracle_migration`.
- DMS replication instance: `oracle-postgresql-migration-dev-replication`, `dms.t3.medium`, single-AZ.
- DMS task: `oracle-postgresql-migration-dev-full-load-cdc`.
- Migration type: `full-load-and-cdc`.
- Target table preparation mode: `DO_NOTHING`.
- DMS task start is manual; Terraform does not automatically start replication.

See [`terraform/README.md`](terraform/README.md) for the current infrastructure inventory, Terraform workflow, feature flags, DMS mappings, IAM resources, and deployment notes. Do not place secrets, local Terraform variable files, backend configuration, state files, or saved plans in source control.

## Six project phases

The project follows six ordered phases. The sequence is intentional: the migration and operational baseline precede analytics, production-readiness validation, and the final multi-source ETL/data warehouse workstream.

### Phase 1 — On-Premises Oracle Source Engineering

Build and baseline the Oracle source environment.

**Scope**
- Build the Windows-hosted VirtualBox/Vagrant environment and RHEL 8.10 Oracle source VM.
- Install and configure Oracle Database 19c Enterprise Edition.
- Configure the CDB/PDB architecture and application PDB `MIGPDB`.
- Establish the four application schemas and realistic source data.
- Engineer Oracle storage, tablespaces, indexes, constraints, sequences, and representative workloads.
- Configure ARCHIVELOG, supplemental logging, RMAN backup/recovery, and source monitoring.
- Prepare the dedicated DMS source account with least-privilege access.
- Establish and validate source connectivity through the AWS reverse-tunnel path.

**Phase gate**
- Source database is available and documented.
- Source object/data baseline is captured.
- Required archive logging, supplemental logging, and DMS privileges are verified.
- Recovery baseline and archive-retention approach are documented.

### Phase 2 — AWS Infrastructure, Schema Conversion & Migration

Provision the AWS migration platform, convert the database schema, and migrate data with DMS.

**Scope**
- Provision the AWS network, subnets, route tables, security groups, endpoints, and supporting services using Terraform.
- Provision the EC2 reverse-tunnel gateway and private Amazon RDS for PostgreSQL target.
- Configure IAM roles, Secrets Manager, KMS, S3 artifacts, CloudWatch, and notifications.
- Deploy the DMS replication instance and Oracle/PostgreSQL endpoints.
- Establish and test Oracle-to-DMS connectivity and DMS-to-RDS connectivity.
- Create the AWS DMS Schema Conversion project and assess the four Oracle schemas.
- Review conversion output and remediate PostgreSQL DDL and compatibility issues.
- Deploy and validate the target schemas, tables, sequences, indexes, and constraints.
- Configure DMS table mappings, Full Load + CDC settings, logging, and premigration assessments.
- Execute Full Load, monitor CDC, and investigate migration errors.
- Reconcile source and target row counts, aggregates, relationships, LOB samples, and sequence behavior.
- Reconcile the historical 12-row source count difference.

**Current checkpoint — November 27, 2026**
- AWS infrastructure and RDS PostgreSQL target deployed.
- DMS replication instance and both endpoints deployed; both endpoint connection tests succeeded.
- DMS Schema Conversion project created; the four schemas were assessed and conversion output reviewed.
- Target schema deployed: 4 schemas, 12 tables, 11 sequences, 29 indexes, and 244 constraints.
- The earlier DMS premigration assessment reported 1 failed and 4 passed checks. The four required Oracle dictionary-view SELECT grants were subsequently verified directly for `DMS_USER`; this grant verification is not a new 5/5 assessment report.
- Oracle supplemental logging verified for all 12 in-scope tables.
- PostgreSQL DMS target permissions granted and verified; all 12 target tables were empty at the latest check.
- DMS Full Load + CDC task created through Terraform and verified in `ready` state.
- DMS Full Load completed. Initial dependency-order errors affected three `PROCUREMENT` tables; the affected parent/child tables were reloaded in dependency order and subsequently completed without Full Load errors. Orphan checks returned zero.

**Phase gate**
- Full Load and CDC complete with no unresolved blocking errors.
- Source-to-target data reconciliation and application validation approved.
- Cutover and rollback procedures rehearsed and explicitly approved.

### Phase 3 — PostgreSQL DBA Operations & Reliability

Establish operational ownership and production-grade database administration for Amazon RDS for PostgreSQL.

**Scope**
- Database and schema administration, roles, authentication, authorization, and least privilege.
- Parameter groups, extensions, connection management, and database configuration.
- Backup strategy, point-in-time recovery (PITR), restore testing, and recovery objectives.
- High availability, Multi-AZ behavior, failover testing, and read-replica concepts where appropriate.
- Performance analysis using PostgreSQL statistics, execution plans, indexing, and query tuning.
- Vacuum, analyze, autovacuum, bloat, and storage management.
- Logging, auditing, monitoring, alarms, capacity planning, and operational automation.
- TLS/security controls, patching strategy, maintenance windows, and incident response.
- Document DBA runbooks and operational procedures.

**Phase gate**
- Backup and restore/PITR evidence captured.
- Availability and failover behavior tested.
- Performance, security, monitoring, and capacity baselines documented.
- DBA operating procedures reviewed.

### Phase 4 — Analytics, Reporting & Business Intelligence

Build analytical and reporting capabilities on the migrated PostgreSQL platform.

**Scope**
- Define analytical requirements, business questions, and measurable KPIs.
- Develop SQL reporting queries, aggregations, and reusable analytical views.
- Design dimensional and reporting structures where justified by requirements.
- Implement fact/dimension relationships, business definitions, and data lineage.
- Validate report results against source/business expectations.
- Develop dashboard-ready datasets and reporting documentation.

**Phase gate**
- Business metrics and definitions are documented.
- Analytical queries and reporting datasets are validated.
- Data lineage and reconciliation evidence are available.

### Phase 5 — Production Readiness & Operational Validation

Demonstrate that the platform and migration are ready for controlled production operation.

**Scope**
- Execute end-to-end functional, integration, performance, security, and operational tests.
- Rehearse backup/restore, recovery, failover, and incident-response procedures.
- Validate database access controls, encryption, network boundaries, logging, and monitoring.
- Test capacity, workload behavior, connection limits, and performance under representative load.
- Review operational costs and resource sizing.
- Finalize deployment, change-management, cutover, rollback, and handover runbooks.
- Obtain explicit approval before any production traffic cutover.

**Phase gate**
- Critical test results meet agreed acceptance criteria.
- RPO/RTO, downtime, monitoring, and support procedures are agreed and documented.
- Cutover and rollback rehearsal is approved.
- Production readiness sign-off is recorded.

### Phase 6 — Multi-Source ETL & Data Warehouse Engineering

This is the final phase and follows the completion of the preceding migration, DBA, analytics, and production-readiness work.

**Scope**
- Retain Apache NiFi 2.12 for ingestion and dataflow processing.
- Use Apache Airflow for orchestration and scheduling.
- Have Airflow trigger NiFi ingestion through the NiFi REST API and monitor execution.
- Integrate multiple source formats and systems, including database extracts and CSV files.
- Build staging, transformation, validation, and target-load patterns.
- Implement incremental processing, upserts, rejected-record handling, audit logging, and reconciliation.
- Implement reusable data warehouse loading patterns, including slowly changing dimensions where appropriate.
- Schedule, monitor, retry, and operationalize end-to-end data pipelines.
- Document lineage, data quality, dependencies, and recovery behavior.

**Phase gate**
- Multi-source pipelines run reliably under orchestration.
- Data quality, audit, rejection, and reconciliation controls are demonstrated.
- Warehouse loads and reporting outputs are validated.
- Operational scheduling and support documentation are complete.

## Repository structure

```text
oracle-to-postgresql-rds-aws-etl/
├── README.md
├── terraform/
│   ├── README.md
│   ├── bootstrap/
│   ├── environments/
│   │   └── dev/
│   ├── modules/
│   │   ├── 1_networking/
│   │   ├── 2_security/
│   │   ├── 3_kms/
│   │   ├── 4_s3/
│   │   ├── 5_postgresql_rds_config/
│   │   ├── 6_postgresql_rds_subnet_group/
│   │   ├── 7_postgresql_rds_instance/
│   │   ├── 8_secrets/
│   │   ├── 9_iam/
│   │   ├── 10_ec2_tunnel_gateway/
│   │   ├── 11_dms/
│   │   ├── 12_schema_conversion/
│   │   └── 13_monitoring/
├── deliverables/
│   ├── Migration Plan Oracle19c_to_PostgreSQL_RDS_AWS_DMS.pptx
│   └── Migration Plan_Oracle19c_to_PostgreSQL_RDS_AWS_DMS.docx
├── scripts/
│   ├── connectivity/
│   │   ├── start-oracle-reverse-tunnel.sh
│   │   └── test-tunnel-from-aws.sh
│   ├── dms/
│   │   ├── check-dms-task-status.sh
│   │   └── monitor-dms-table-progress.sh
│   ├── postgres/
│   │   ├── schema-review/
│   │   │   └── oracle_to_postgresql_schema_review_v1.sql
│   │   ├── create-postgres-dms-target-role.sql
│   │   ├── grant-postgres-dms-target.sql
│   │   └── validate-postgres-target.sh
│   └── secrets/
│       ├── populate-oracle-source-secret.ps1
│       ├── populate-postgres-target-secret.ps1
│       └── populate-schema-conversion-oracle-secret.ps1
├── phase-1-oracle-source/
├── phase-2-aws-migration/
├── phase-3-postgresql-dba/
├── phase-4-analytics-reporting/
├── phase-5-production-readiness/
└── phase-6-multi-source-etl-dwh/
```

The phase directories above describe the intended documentation/workstream organization. Add or rename directories to match the actual repository as the implementation evolves; do not move existing project files without reviewing their references.

## Working principles and safety

- **Terraform is the source of truth for AWS infrastructure.** Create and manage AWS infrastructure through Terraform; do not manually provision replacement resources in the AWS console.
- Keep this project’s Terraform state, S3 backend key, VPC, resource names, and target database separate from any other Oracle migration project.
- Review every Terraform plan before applying it. Use a fresh plan for each change.
- Do not commit `terraform.tfvars`, `backend.hcl`, Terraform state, saved plan files, `.terraform/`, secret values, credentials, access keys, certificates, or private keys.
- Commit `.terraform.lock.hcl`.
- Store database credentials in AWS Secrets Manager. Never place passwords or secret JSON in source control.
- Use least-privilege service and database accounts; do not grant DBA or broad administrative privileges to DMS accounts.
- Preserve Oracle archive logs needed by DMS CDC. Do not allow RMAN cleanup to remove logs before DMS has consumed them.
- Keep the DMS task manually controlled. Do not enable automatic task startup through Terraform unless the operating procedure is deliberately changed and reviewed.
- Treat successful endpoint tests, a ready DMS task, a completed Full Load, CDC catch-up, data reconciliation, and production cutover as distinct milestones.
- Record only evidenced completion. A configured resource is not proof of a successful migration or production cutover.
- Do not perform production cutover without explicit approval and an approved rollback plan.

