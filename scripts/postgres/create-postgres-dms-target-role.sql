-- PURPOSE: Create the dedicated least-privilege PostgreSQL login used by the AWS DMS target endpoint.
-- WHY: DMS should not connect as the RDS master user; this role is separate from the administrative login.
-- SECURITY: Set the password interactively with \password and store it in the matching Secrets Manager secret.
-- TIMING: Run only after the RDS instance and initial database have been created and verified.
-- Run with psql as the RDS master user after RDS is available.
-- The role is created without a password in this file; no credential is stored in Git.
CREATE ROLE dms_target LOGIN;

-- In the interactive psql session, set the password using the hidden prompt:
-- \password dms_target
-- Then populate the Terraform-created postgres DMS target secret with:
-- scripts/populate-postgres-target-secret.ps1
