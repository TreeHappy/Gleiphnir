#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

key_opt=()
if [ -f "$ADMIN_SSH_PRIV_PATH" ]; then
  key_opt=(-i "$ADMIN_SSH_PRIV_PATH")
fi

ssh_admin() {
  if [ "$NETWORK_MODE" = "user" ]; then
    ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "$@"
  else
    if ssh "${key_opt[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 "${ADMIN_USER}@${VM_IP}" "$@" 2>/dev/null; then
      return 0
    fi
    ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "$@"
  fi
}

ssh_admin "echo '=== podman images ==='; podman images; echo ''; echo '=== podman info (storage) ==='; podman info 2>&1 | head -40; echo ''; echo '=== container entrypoint check ==='; podman run --rm $CONTAINER_IMAGE cat /etc/sandbox/mise.toml 2>&1 | head -30; echo ''; podman run --rm $CONTAINER_IMAGE mise --version 2>&1 | head -5"
