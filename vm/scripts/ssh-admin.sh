#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

key_opt=()
if [ -f "$ADMIN_SSH_PRIV_PATH" ]; then
  key_opt=(-i "$ADMIN_SSH_PRIV_PATH")
fi
extra_args=("$@")

if [ "$NETWORK_MODE" = "user" ]; then
  echo "Connecting via host forward 127.0.0.1:$HOST_SSH_FORWARD_PORT (user-mode NAT) ..."
  exec ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "${ADMIN_USER}@127.0.0.1" "${extra_args[@]}"
else
  # Try direct VM IP first, fall back to host forward (useful externally)
  echo "Connecting to ${ADMIN_USER}@${VM_IP} (bridge) ..."
  if ssh "${key_opt[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 "${ADMIN_USER}@${VM_IP}" "${extra_args[@]}" 2>/dev/null; then
    exit 0
  fi
  echo "Direct connect failed — trying host forward 127.0.0.1:$HOST_SSH_FORWARD_PORT ..."
  exec ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "${ADMIN_USER}@127.0.0.1" "${extra_args[@]}"
fi
