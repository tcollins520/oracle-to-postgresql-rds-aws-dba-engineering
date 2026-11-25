#!/usr/bin/env bash
# Read-only PostgreSQL target schema/table/privilege check.
# Connect as the DMS target role to validate its effective privileges.
#
# Required environment:
#   PGHOST, PGPORT, PGDATABASE, PGUSER
# Optional:
#   PGPASSWORD (prefer a secure prompt or approved secret-injection method)
#
# Example:
#   PGHOST=127.0.0.1 PGPORT=15432 PGDATABASE=oracle_migration \
#   PGUSER=dms_user ./validate-postgres-target.sh

set -euo pipefail

: "${PGHOST:?Set PGHOST (for this project, usually 127.0.0.1 through the SSM tunnel)}"
: "${PGPORT:?Set PGPORT (for this project, usually 15432 through the SSM tunnel)}"
: "${PGDATABASE:?Set PGDATABASE (oracle_migration)}"
: "${PGUSER:?Set PGUSER (dms_user to check DMS privileges)}"

command -v psql >/dev/null 2>&1 || {
  echo "ERROR: psql is required. Install PostgreSQL client tools and add psql to PATH." >&2
  exit 1
}

echo "PostgreSQL target validation"
echo "Host: ${PGHOST}:${PGPORT}"
echo "Database: ${PGDATABASE}"
echo "Role: ${PGUSER}"
echo "Password is not displayed."
echo

psql -X -v ON_ERROR_STOP=1 -P pager=off \
  -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" <<'SQL'
\echo '1. Connection identity'
SELECT current_database() AS database_name,
       current_user AS connected_role,
       inet_server_addr() AS server_address,
       inet_server_port() AS server_port;

\echo
\echo '2. Required schema USAGE privileges'
WITH expected(schema_name) AS (
    VALUES ('common'), ('finance'), ('grants'), ('procurement')
)
SELECT schema_name,
       has_schema_privilege(current_user, schema_name, 'USAGE') AS has_usage
FROM expected
ORDER BY schema_name;

\echo
\echo '3. Target table inventory and effective DMS privileges'
WITH expected(schema_name, table_name) AS (
    VALUES
      ('common', 'dim_agency'),
      ('common', 'dim_date'),
      ('common', 'dim_geography'),
      ('common', 'dim_program'),
      ('finance', 'fact_budget_execution'),
      ('finance', 'fact_financial_transaction'),
      ('grants', 'dim_recipient'),
      ('grants', 'fact_grant_application'),
      ('procurement', 'dim_contract'),
      ('procurement', 'dim_vendor'),
      ('procurement', 'fact_contract_payment'),
      ('procurement', 'fact_purchase_order')
)
SELECT e.schema_name,
       e.table_name,
       to_regclass(format('%I.%I', e.schema_name, e.table_name)) IS NOT NULL AS table_exists,
       CASE WHEN to_regclass(format('%I.%I', e.schema_name, e.table_name)) IS NOT NULL
            THEN has_table_privilege(current_user, format('%I.%I', e.schema_name, e.table_name), 'SELECT')
            ELSE false END AS can_select,
       CASE WHEN to_regclass(format('%I.%I', e.schema_name, e.table_name)) IS NOT NULL
            THEN has_table_privilege(current_user, format('%I.%I', e.schema_name, e.table_name), 'INSERT')
            ELSE false END AS can_insert,
       CASE WHEN to_regclass(format('%I.%I', e.schema_name, e.table_name)) IS NOT NULL
            THEN has_table_privilege(current_user, format('%I.%I', e.schema_name, e.table_name), 'UPDATE')
            ELSE false END AS can_update,
       CASE WHEN to_regclass(format('%I.%I', e.schema_name, e.table_name)) IS NOT NULL
            THEN has_table_privilege(current_user, format('%I.%I', e.schema_name, e.table_name), 'DELETE')
            ELSE false END AS can_delete
FROM expected e
ORDER BY e.schema_name, e.table_name;

\echo
\echo '4. Actual target row counts (expected to be zero before initial Full Load)'
SELECT 'common.dim_agency' AS table_name, count(*) AS row_count FROM common.dim_agency
UNION ALL SELECT 'common.dim_date', count(*) FROM common.dim_date
UNION ALL SELECT 'common.dim_geography', count(*) FROM common.dim_geography
UNION ALL SELECT 'common.dim_program', count(*) FROM common.dim_program
UNION ALL SELECT 'finance.fact_budget_execution', count(*) FROM finance.fact_budget_execution
UNION ALL SELECT 'finance.fact_financial_transaction', count(*) FROM finance.fact_financial_transaction
UNION ALL SELECT 'grants.dim_recipient', count(*) FROM grants.dim_recipient
UNION ALL SELECT 'grants.fact_grant_application', count(*) FROM grants.fact_grant_application
UNION ALL SELECT 'procurement.dim_contract', count(*) FROM procurement.dim_contract
UNION ALL SELECT 'procurement.dim_vendor', count(*) FROM procurement.dim_vendor
UNION ALL SELECT 'procurement.fact_contract_payment', count(*) FROM procurement.fact_contract_payment
UNION ALL SELECT 'procurement.fact_purchase_order', count(*) FROM procurement.fact_purchase_order
ORDER BY table_name;
SQL

echo
echo "Read-only validation finished. Review all result rows; this script does not grant privileges or modify data."
