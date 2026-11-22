#!/usr/bin/env bash
# PURPOSE: Check that the gateway is listening on the private reverse-tunnel address and that the TCP port accepts connections.
# SCOPE: This validates the gateway-side listener only; it does not replace an AWS DMS endpoint TestConnection.
# RUN: Execute from an SSM session on the EC2 gateway after the Oracle VM reverse tunnel is established.
set -euo pipefail

# Run from an SSM session on the EC2 gateway after the Oracle VM tunnel is active.
PRIVATE_IP="${1:?Usage: test-tunnel-from-aws.sh <gateway-private-ip> [tunnel-port]}"
TUNNEL_PORT="${2:-11521}"

printf 'Checking SSH reverse-tunnel listener on %s:%s...\n' "$PRIVATE_IP" "$TUNNEL_PORT"
ss -lntp | grep -F "${PRIVATE_IP}:${TUNNEL_PORT}"
timeout 5 bash -c "cat < /dev/null > /dev/tcp/${PRIVATE_IP}/${TUNNEL_PORT}"
echo "Gateway listener is accepting TCP connections. Run AWS DMS TestConnection for an end-to-end endpoint test."
