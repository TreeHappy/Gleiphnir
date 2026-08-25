#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

echo "=== Network mode: $NETWORK_MODE ==="
echo ""
if [ "$NETWORK_MODE" = "user" ]; then
  echo "QEMU user-mode NAT: host 127.0.0.1:$HOST_SSH_FORWARD_PORT → VM :22"
  echo "No bridge/TAP. VM cannot see real client IPs — filter on host instead."
  exit 0
fi

echo "Bridge: $BRIDGE_NAME  TAP: $TAP_NAME  VM: $VM_IP/24  Host forward: :$HOST_SSH_FORWARD_PORT → $VM_IP:22"
echo ""

echo "--- ip addr ---"
ip addr show "$BRIDGE_NAME" 2>&1 || echo "Bridge $BRIDGE_NAME not found"
echo ""
ip addr show "$TAP_NAME" 2>&1 || echo "TAP $TAP_NAME not found"
echo ""

echo "--- bridge members ---"
bridge link show 2>/dev/null || brctl show 2>/dev/null || echo "(no bridge tool output)"
echo ""

if command -v iptables >/dev/null 2>&1; then
  echo "--- iptables nat ---"
  sudo iptables -t nat -L -n -v 2>&1 | head -40 || iptables -t nat -L -n -v 2>&1 | head -40 || true
  echo ""
  echo "--- iptables filter FORWARD ---"
  sudo iptables -L FORWARD -n -v 2>&1 | head -20 || iptables -L FORWARD -n -v 2>&1 | head -20 || true
fi
