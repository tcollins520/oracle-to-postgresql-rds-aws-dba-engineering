#!/usr/bin/env bash
# Read-only table-level Full Load / CDC statistics for the DMS task.
# Usage: ./monitor-dms-table-progress.sh
# Optional overrides: AWS_REGION, DMS_TASK_ARN, AWS_PROFILE

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
DMS_TASK_ARN="${DMS_TASK_ARN:-arn:aws:dms:us-east-1:059317926607:task:MIDUXT5YWVC6XGGBQSLRCVAGSM}"

command -v aws >/dev/null 2>&1 || {
  echo "ERROR: AWS CLI is required." >&2
  exit 1
}

echo "DMS table-level statistics"
echo "Region: ${AWS_REGION}"
echo "Task ARN: ${DMS_TASK_ARN}"
echo

aws dms describe-table-statistics \
  --replication-task-arn "${DMS_TASK_ARN}" \
  --region "${AWS_REGION}" \
  --query 'TableStatistics[].{Schema: SchemaName,Table: TableName,State: TableState,FullLoadRows: FullLoadRows,Inserts: Inserts,Updates: Updates,Deletes: Deletes,FullLoadErrors: FullLoadErrorRows,ValidationFailed: ValidationFailedRecords,ValidationPending: ValidationPendingRecords}' \
  --output table

echo
echo "Tip: Run again to refresh the snapshot. This script does not change the task."
