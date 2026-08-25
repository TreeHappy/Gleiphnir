#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

action="${1:-}"
ip="${2:-}"

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

case "$action" in
  allow)
    if [ -z "$ip" ]; then echo "Usage: $0 allow <IP>[/prefix]" >&2; exit 1; fi
    ssh_admin "sudo /usr/local/bin/sandbox-firewall allow '$ip'"
    ;;
  deny)
    if [ -z "$ip" ]; then echo "Usage: $0 deny <IP>[/prefix]" >&2; exit 1; fi
    ssh_admin "sudo /usr/local/bin/sandbox-firewall deny '$ip'"
    ;;
  remove|delete|unallow|undeny)
    if [ -z "$ip" ]; then echo "Usage: $0 remove <IP>[/prefix]" >&2; exit 1; fi
    ssh_admin "sudo /usr/local/bin/sandbox-firewall remove '$ip'"
    ;;
  list|show|status)
    ssh_admin "sudo /usr/local/bin/sandbox-firewall list"
    ;;
  *)
    echo "Usage: $0 allow|deny|remove|list <IP>" >&2
    exit 1
    ;;
esac
