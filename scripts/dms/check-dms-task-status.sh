#!/usr/bin/env bash
# Read-only status check for the Oracle 19c -> Amazon RDS for PostgreSQL DMS task.
# Usage: ./check-dms-task-status.sh
# Optional overrides: AWS_REGION, DMS_TASK_ARN, AWS_PROFILE

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
DMS_TASK_ARN="${DMS_TASK_ARN:-arn:aws:dms:us-east-1:059317926607:task:MIDUXT5YWVC6XGGBQSLRCVAGSM}"

command -v aws >/dev/null 2>&1 || {
  echo "ERROR: AWS CLI is required." >&2
  exit 1
}

echo "DMS task status"
echo "Region: ${AWS_REGION}"
echo "Task ARN: ${DMS_TASK_ARN}"
echo

aws dms describe-replication-tasks \
  --filters "Name=replication-task-arn,Values=${DMS_TASK_ARN}" \
  --region "${AWS_REGION}" \
  --query 'ReplicationTasks[0].{TaskIdentifier:ReplicationTaskIdentifier,Status:Status,MigrationType:MigrationType,StopReason:StopReason,ReplicationInstanceArn:ReplicationInstanceArn}' \
  --output table

echo
echo "Note: This script is read-only. It does not start, stop, reload, or modify the task."
