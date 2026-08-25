#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

timeout_secs=180
interval=3
elapsed=0

key_opt=()
if [ -f "$ADMIN_SSH_PRIV_PATH" ]; then
  key_opt=(-i "$ADMIN_SSH_PRIV_PATH")
fi

# Determine target list to poll (direct + forward in bridge mode, forward only in user mode)
targets=()
if [ "$NETWORK_MODE" = "user" ]; then
  targets=("127.0.0.1:$HOST_SSH_FORWARD_PORT")
else
  targets=("${VM_IP}:22" "127.0.0.1:$HOST_SSH_FORWARD_PORT")
fi

echo "Waiting for VM SSH (timeout ${timeout_secs}s, mode: $NETWORK_MODE) ..."

try_ssh() {
  local host port
  IFS=: read -r host port <<<"$1"
  if [ "$host" = "127.0.0.1" ]; then
    ssh "${key_opt[@]}" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=2 "${ADMIN_USER}@${host}" true 2>/dev/null
  else
    ssh "${key_opt[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=2 "${ADMIN_USER}@${host}" true 2>/dev/null
  fi
}

while [ "$elapsed" -lt "$timeout_secs" ]; do
  for target in "${targets[@]}"; do
    if try_ssh "$target"; then
      echo "VM SSH is up at $target (${elapsed}s elapsed)"
      # Also check cloud-init finished
      echo "Checking cloud-init status ..."
      ssh_cmd_target=""
      if [[ "$target" == "127.0.0.1:"* ]]; then
        port="${target#*:}"
        ssh "${key_opt[@]}" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "cloud-init status --wait 2>&1 | tail -5; echo ---; systemctl is-active podman 2>&1 | head -5; echo ---; podman images 2>&1 | head -10" 2>/dev/null || true
      else
        host="${target%:*}"
        ssh "${key_opt[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@${host}" "cloud-init status --wait 2>&1 | tail -5; echo ---; systemctl is-active podman 2>&1 | head -5; echo ---; podman images 2>&1 | head -10" 2>/dev/null || true
      fi
      exit 0
    fi
  done
  printf "  %3ds — not yet (targets: %s)\n" "$elapsed" "${targets[*]}"
  sleep "$interval"
  elapsed=$((elapsed + interval))
done

echo "Timed out after ${timeout_secs}s waiting for VM SSH" >&2
echo "Check: task vm:console  or  task vm:info" >&2
exit 1
