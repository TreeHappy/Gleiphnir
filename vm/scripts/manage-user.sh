#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

action="${1:-}"
user="${2:-}"
key_path="${3:-}"

if [ -z "$action" ]; then
  echo "Usage: $0 add|remove|list [user] [key.pub]" >&2
  exit 1
fi

# Build SSH invocation for admin
key_opt=()
if [ -f "$ADMIN_SSH_PRIV_PATH" ]; then
  key_opt=(-i "$ADMIN_SSH_PRIV_PATH")
fi

ssh_admin() {
  if [ "$NETWORK_MODE" = "user" ]; then
    ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "$@"
  else
    # try direct, fallback to forward
    if ssh "${key_opt[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 "${ADMIN_USER}@${VM_IP}" "$@" 2>/dev/null; then
      return 0
    fi
    ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "$@"
  fi
}

case "$action" in
  add)
    if [ -z "$user" ]; then echo "Usage: $0 add <username> [key.pub]" >&2; exit 1; fi
    pubkey=""
    if [ -n "$key_path" ] && [ -f "$key_path" ]; then
      pubkey="$(cat "$key_path")"
    elif [ -n "$key_path" ]; then
      # treat as literal key string if file not found
      pubkey="$key_path"
    else
      # try default user key
      for cand in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub ~/.ssh/id_ecdsa.pub; do
        if [ -f "$cand" ]; then pubkey="$(cat "$cand")"; echo "Using key $cand"; break; fi
      done
      if [ -z "$pubkey" ]; then
        echo "No key file provided and no default key found at ~/.ssh/id_*.pub" >&2
        echo "Usage: $0 add $user /path/to/key.pub" >&2
        exit 1
      fi
    fi
    echo "Creating sandbox user '$user' ..."
    # Escape pubkey for remote shell — base64 to avoid quoting issues
    b64="$(printf '%s' "$pubkey" | base64 -w0)"
    ssh_admin "echo '$b64' | base64 -d | sudo /usr/local/bin/sandbox-user add '$user' --key-file /dev/stdin"
    echo "Done. Test: ssh ${user}@${VM_IP}  (or ssh -p $HOST_SSH_FORWARD_PORT ${user}@127.0.0.1)"
    ;;
  remove)
    if [ -z "$user" ]; then echo "Usage: $0 remove <username>" >&2; exit 1; fi
    echo "Removing sandbox user '$user' ..."
    ssh_admin "sudo /usr/local/bin/sandbox-user remove '$user'"
    ;;
  list)
    ssh_admin "sudo /usr/local/bin/sandbox-user list || ls -1 /home/ 2>&1 | head -30; echo '--- workspaces ---'; ls -1 /srv/sandbox/ 2>&1 | head -30"
    ;;
  *)
    echo "Unknown action: $action (expected add|remove|list)" >&2
    exit 1
    ;;
esac
