-- PURPOSE: Grant the DMS target login the table, schema, and sequence permissions required for replication.
-- WHY: The DMS target endpoint needs DML rights on converted objects but does not need PostgreSQL superuser access.
-- PREREQUISITE: Review and apply the converted target DDL first; confirm actual schema names and object ownership.
-- OPERATIONS: Repeat grants or configure default privileges for the role that creates future target objects.
-- Run with psql as the RDS master user AFTER Schema Conversion DDL has been reviewed and applied.
-- These statements assume the converted target schemas are lowercase. Adjust them to the actual
-- schema names and owners emitted by the reviewed DMS Schema Conversion output.

GRANT CONNECT ON DATABASE oracle_migration TO dms_target;
GRANT USAGE ON SCHEMA common, finance, grants, procurement TO dms_target;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA common TO dms_target;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finance TO dms_target;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA grants TO dms_target;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA procurement TO dms_target;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA common TO dms_target;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finance TO dms_target;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA grants TO dms_target;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA procurement TO dms_target;

-- Repeat/extend these grants for any new objects created after the first grant pass.
-- Default privileges must be configured for the role that owns/creates future converted objects.
