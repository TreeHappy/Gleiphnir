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

echo "Building sandbox container image inside VM ($CONTAINER_IMAGE) ..."
ssh_admin "sudo /usr/local/lib/sandbox/build-container.sh 2>&1 | tail -100"
echo ""
echo "Verifying ..."
ssh_admin "podman images | grep -E 'REPOSITORY|sandbox' || podman images | head -20"
