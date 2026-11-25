#!/usr/bin/env bash
# PURPOSE: Establish the persistent outbound SSH reverse tunnel from the RHEL Oracle source VM to the EC2 gateway.
# ARCHITECTURE: Oracle VM -> outbound SSH to gateway public IP; DMS -> gateway private IP:11521 -> forwarded Oracle listener 10.0.2.15:1521.
# SECURITY: The private SSH key stays on the Oracle VM with restrictive permissions; only its public key is installed on the gateway.
# OPERATIONS: Replace Terraform output placeholders, verify host-key trust, then run under the dedicated tunnel account.
set -euo pipefail

# Run on the RHEL Oracle source VM as oracleadmin after the EC2 gateway exists.
# Store the private key under /home/oracleadmin/.ssh and chmod 600.
GATEWAY_PUBLIC_IP="REPLACE_WITH_TERRAFORM_OUTPUT"
GATEWAY_PRIVATE_IP="REPLACE_WITH_TERRAFORM_OUTPUT"
PRIVATE_KEY="/home/oracleadmin/.ssh/oracle-dms-tunnel"
TUNNEL_USER="oracle-tunnel"
TUNNEL_PORT="11521"
ORACLE_HOST="10.0.2.15"
ORACLE_PORT="1521"

exec ssh -NT \
  -i "$PRIVATE_KEY" \
  -o IdentitiesOnly=yes \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o StrictHostKeyChecking=accept-new \
  -R "${GATEWAY_PRIVATE_IP}:${TUNNEL_PORT}:${ORACLE_HOST}:${ORACLE_PORT}" \
  "${TUNNEL_USER}@${GATEWAY_PUBLIC_IP}"
