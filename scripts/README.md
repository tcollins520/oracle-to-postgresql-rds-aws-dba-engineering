# Migration Project Scripts — Purpose and Operating Guide

This directory contains the helper scripts used to prepare, connect, configure, validate, and monitor the Oracle 19c to Amazon RDS for PostgreSQL migration.

The scripts are grouped by operational responsibility. They are not all intended to be run at the same time: some are setup/deployment artifacts, some are connectivity utilities, and some are read-only checks used during migration execution.

> **Current migration checkpoint:** The AWS DMS Full Load + CDC task has been created and is in `ready` state. Full Load has not been started. Run the read-only checks before starting the task. Do not rerun the schema deployment SQL against a target after data has been loaded.

## Directory layout

```text
scripts/
├── README.md
├── connectivity/
│   ├── start-oracle-reverse-tunnel.sh
│   └── test-tunnel-from-aws.sh
├── dms/
│   ├── check-dms-task-status.sh
│   └── monitor-dms-table-progress.sh
├── postgres/
│   ├── create-postgres-dms-target-role.sql
│   ├── grant-postgres-dms-target.sql
│   ├── validate-postgres-target.sh
│   └── schema-review/
│       └── oracle_to_postgresql_schema_review_v1.sql
└── secrets/
    ├── populate-oracle-source-secret.ps1
    ├── populate-postgres-target-secret.ps1
    └── populate-schema-conversion-oracle-secret.ps1
```

If the current checkout still has these files directly under `scripts/`, that is fine. The layout above is the recommended logical organization; moving existing scripts requires updating any paths or documentation that refer to them.

---

## 1. Connectivity scripts

These scripts establish and verify the network path between the on-premises Oracle source and AWS DMS.

### `start-oracle-reverse-tunnel.sh`

**Purpose**

Starts the reverse tunnel from the Oracle source environment to the AWS tunnel gateway so the DMS replication instance can reach the Oracle listener through the configured private connectivity path.

**Why it exists**

The Oracle source database is hosted in a virtualized on-premises-style environment and is not directly exposed to the public internet. The reverse tunnel provides the controlled network path used by DMS without making the Oracle listener publicly accessible.

**When to use it**

- When the Oracle source VM is restarted.
- When the reverse tunnel process is no longer running.
- Before testing Oracle-to-DMS source connectivity.

**Execution context**

Git Bash, from the project environment where the script and its required SSH configuration are available. Confirm the script's configured host, port, key/identity method, and tunnel command before running it. Do not substitute an SSH key or connection method that is not part of the approved project setup.

### `test-tunnel-from-aws.sh`

**Purpose**

Tests whether the AWS-side host can reach the Oracle listener through the reverse tunnel.

**Why it exists**

A running tunnel process alone does not prove that the remote Oracle listener is reachable. This check validates the network path from the AWS side before troubleshooting DMS endpoint connectivity.

**When to use it**

- After starting or restarting the reverse tunnel.
- When the DMS Oracle endpoint connection test fails.
- When investigating a source connectivity interruption.

**Execution context**

Git Bash / AWS-side shell as defined by the script. Review the script's target host and port before use. A successful network test confirms reachability only; it does not validate Oracle credentials, privileges, or DMS CDC readiness.

---

## 2. AWS DMS scripts

These scripts inspect the DMS replication task and its table-level migration progress. They are designed to be read-only.

### `check-dms-task-status.sh`

**Purpose**

Displays the configured DMS task's identifier, status, migration type, stop reason, and replication instance ARN.

**Why it exists**

It provides a quick, repeatable status check without repeatedly composing a long AWS CLI command. It helps distinguish a task that is configured and ready from one that is actively running, stopped, failed, or completed.

**When to use it**

- Before starting Full Load.
- After starting the task.
- During migration troubleshooting.
- Before and after planned task operations.

**Project defaults**

- Region: `us-east-1`
- Task identifier: `oracle-postgresql-migration-dev-full-load-cdc`
- Task ARN: `arn:aws:dms:us-east-1:059317926607:task:MIDUXT5YWVC6XGGBQSLRCVAGSM`

The script supports environment-variable overrides for `AWS_REGION` and `DMS_TASK_ARN`.

**Safety**

This script calls DMS describe operations only. It does not start, stop, reload, or modify the task.

### `monitor-dms-table-progress.sh`

**Purpose**

Displays DMS table-level statistics, including table state, Full Load rows, inserts, updates, deletes, Full Load error rows, and available validation counters.

**Why it exists**

Task-level status does not show which individual tables have loaded, are still loading, or have encountered errors. Table statistics help identify slow or failed tables and provide evidence for migration monitoring.

**When to use it**

- During Full Load.
- After Full Load to review table completion and error counts.
- During CDC to inspect ongoing table activity and available validation statistics.

**Safety and interpretation**

This script reads DMS table statistics only. It does not change the task.

Before Full Load, statistics may be empty or show no rows loaded. After Full Load starts, nonzero row counts are expected. Interpret counters according to the current migration phase; table statistics alone do not establish that source and target data reconcile.

---

## 3. PostgreSQL target scripts

These scripts prepare or inspect the DMS target role and the converted PostgreSQL schema.

### `create-postgres-dms-target-role.sql`

**Purpose**

Creates the PostgreSQL role used by AWS DMS to connect to the target database.

**Why it exists**

A dedicated DMS target role separates replication permissions from the human DBA or migration-administration account. This supports least-privilege access and makes the migration service account easier to audit and manage.

**When to use it**

During initial target security setup, or when rebuilding the target security configuration in a controlled environment.

**Important**

This is a setup script, not a routine monitoring script. Review its role attributes and password handling before execution. Do not commit passwords or embed reusable secrets in SQL source control.

### `grant-postgres-dms-target.sql`

**Purpose**

Grants the DMS target role the database/schema/table permissions required to apply migrated data to the target objects.

**Why it exists**

Creating a login role does not automatically give it permission to use schemas or write to tables owned by another role. The grants establish the access DMS needs while keeping ownership with the designated database administration role.

**When to use it**

After creating the DMS target role and creating or changing the target schemas/tables. Re-review grants if new schemas or tables are added.

**Important**

This is a privilege-changing script. Run it using an authorized database owner/administrator account, review the target database and role names first, and do not run it merely as a status check.

### `validate-postgres-target.sh`

**Purpose**

Connects to PostgreSQL using the configured `psql` client and checks:
- Database connection identity.
- `USAGE` access to the four target schemas.
- Existence of the 12 expected target tables.
- Effective `SELECT`, `INSERT`, `UPDATE`, and `DELETE` privileges for the connected role.
- Current row counts in the 12 target tables.

**Why it exists**

It provides a repeatable pre-migration readiness check for the DMS target. It helps catch missing tables or insufficient permissions before Full Load begins.

**When to use it**

- Before starting Full Load, connecting as `dms_user`.
- After changing target grants.
- During troubleshooting if DMS reports target permission errors.

**Connection requirements**

The project commonly uses the SSM port-forwarding session to reach RDS locally:

```bash
export PGHOST=127.0.0.1
export PGPORT=15432
export PGDATABASE=oracle_migration
export PGUSER=dms_user

bash scripts/postgres/validate-postgres-target.sh
```

The `psql` client must be installed. Use the approved secure password prompt or secret-injection method; do not hardcode passwords in this script or commit them.

**Interpretation**

The row-count section is a pre-load baseline. Zero rows were expected before the initial Full Load. Once Full Load starts, nonzero counts are expected and should not be treated as a failure.

### `schema-review/oracle_to_postgresql_schema_review_v1.sql`

**Purpose**

Contains the reviewed PostgreSQL DDL working copy derived from AWS DMS Schema Conversion output. It creates the converted target schemas and database objects, including sequences, tables, indexes, and constraints.

**Why it exists**

The raw conversion output required review before deployment. The working copy records the reviewed DDL used to build the PostgreSQL target, including the removal of obsolete `WITH (OIDS=FALSE)` table clauses while preserving the intended object definitions.

**Deployment record**

This SQL file was executed successfully against `oracle_migration` on Amazon RDS for PostgreSQL 18.6. The deployed object inventory was reconciled to:

| Object | Deployed count |
|---|---:|
| Schemas | 4 |
| Tables | 12 |
| Sequences | 11 |
| Indexes | 29 |
| Constraints | 244 |

The 11 sequences were retained without attaching `nextval()` defaults to table columns. Their application-side usage and final sequence-value reconciliation remain separate migration-validation items.

**When to use it**

- As the reviewed DDL record for the target schema deployment.
- When rebuilding a fresh, empty target environment after reviewing the environment and execution plan.

**Critical caution**

Do not rerun this DDL against the active migration target after Full Load has populated data. It is not a data-load script, a schema-drift repair script, or a routine validation script. Review any re-execution carefully, especially `CREATE`, `ALTER`, and constraint statements.

---

## 4. Secrets Manager scripts

These PowerShell scripts populate the project secrets in AWS Secrets Manager. They are Windows PowerShell scripts, not Git Bash scripts.

### `populate-oracle-source-secret.ps1`

**Purpose**

Populates the AWS Secrets Manager secret used for the Oracle source connection.

**Why it exists**

DMS and related migration components need Oracle connection credentials. Storing those credentials in Secrets Manager avoids placing database passwords directly in Terraform configuration, command history, or source-controlled files.

**When to use it**

During initial secret setup or an approved credential rotation. Do not run it casually during an active migration because changing the source credential can affect connectivity.

### `populate-postgres-target-secret.ps1`

**Purpose**

Populates the Secrets Manager secret used for the PostgreSQL target connection.

**Why it exists**

The DMS target endpoint requires target database credentials. Secrets Manager centralizes the credential and supports controlled access through IAM.

**When to use it**

During initial target secret setup or an approved credential rotation. Confirm which DMS endpoint and secret reference use the secret before changing it.

### `populate-schema-conversion-oracle-secret.ps1`

**Purpose**

Populates the Oracle credentials used by the AWS DMS Schema Conversion workflow.

**Why it exists**

Schema Conversion uses source database metadata access to assess Oracle objects and generate PostgreSQL conversion output. Its credential is managed separately from the DMS replication endpoint secret so the two workflows can have distinct access and lifecycle controls.

**When to use it**

During Schema Conversion project setup or an approved credential rotation. It is not required for routine DMS table-progress monitoring.

**Security requirements for all secret scripts**

- Run only from the intended Windows PowerShell environment.
- Inspect the script before execution to understand how it obtains and transmits credentials.
- Never paste secret values into chat, commit them, or place them in README files.
- Do not enable verbose/debug output that could print passwords.
- Limit IAM access to the required Secrets Manager operations and secret ARNs.
- Treat secret rotation as a coordinated change that may require endpoint retesting.

---

## 5. Recommended operating sequence

Use the scripts in the order appropriate to the migration milestone.

### Before Full Load

1. Confirm the Oracle reverse tunnel is running with `start-oracle-reverse-tunnel.sh`.
2. Verify the AWS-side path with `test-tunnel-from-aws.sh`.
3. Check DMS task state with `check-dms-task-status.sh`.
4. Validate target schemas, permissions, and baseline row counts with `validate-postgres-target.sh` using `dms_user`.
5. Confirm the DMS endpoints and premigration assessment are successful in AWS DMS.
6. Start the DMS task only through the approved, explicitly reviewed operating procedure.

The schema-review SQL is already deployed; do not rerun it as part of this checklist.

### During Full Load

1. Check task state with `check-dms-task-status.sh`.
2. Inspect per-table progress with `monitor-dms-table-progress.sh`.
3. Investigate table errors before treating Full Load as complete.
4. Preserve Oracle archive logs required for CDC.

### During CDC and after Full Load

1. Continue checking task state and table statistics.
2. Review CDC latency and task logs in the AWS DMS console/CloudWatch; the current scripts do not yet provide a dedicated CDC-latency report.
3. Perform source-to-target row-count and data-content reconciliation using a separately designed reconciliation procedure.
4. Validate sequence behavior and application functionality before cutover.

---

## 6. Script safety classification

| Script | Category | Changes infrastructure/data/permissions? |
|---|---|---|
| `start-oracle-reverse-tunnel.sh` | Connectivity operation | Starts a tunnel process; does not change database data |
| `test-tunnel-from-aws.sh` | Connectivity test | Read-only network test |
| `check-dms-task-status.sh` | DMS monitoring | Read-only |
| `monitor-dms-table-progress.sh` | DMS monitoring | Read-only |
| `create-postgres-dms-target-role.sql` | Database setup | Creates a role |
| `grant-postgres-dms-target.sql` | Database security | Changes privileges |
| `validate-postgres-target.sh` | Database validation | Read-only |
| `oracle_to_postgresql_schema_review_v1.sql` | Schema deployment | Creates/alters database objects |
| `populate-oracle-source-secret.ps1` | Secret provisioning | Creates/updates a secret value |
| `populate-postgres-target-secret.ps1` | Secret provisioning | Creates/updates a secret value |
| `populate-schema-conversion-oracle-secret.ps1` | Secret provisioning | Creates/updates a secret value |

## 7. General operating rules

- Run scripts from a known working directory and verify the target account, region, database, and environment first.
- Prefer read-only validation before any state-changing operation.
- Do not put passwords, access keys, tokens, private keys, or secret JSON in scripts or Git.
- Do not start or stop DMS implicitly from a monitoring script.
- Do not rerun role, grant, or schema-deployment scripts without reviewing their effects.
- Preserve source Oracle archive logs while DMS CDC may still need them.
- Treat DMS task readiness, Full Load completion, CDC catch-up, reconciliation, and cutover as separate milestones.
- Update this README whenever scripts are added, renamed, moved, or their behavior changes.

