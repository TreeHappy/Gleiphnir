#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if [ "$NETWORK_MODE" = "user" ]; then
  echo "NETWORK_MODE=user — nothing to tear down."
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "network-down.sh must be run as root (use: task network:down  or  sudo bash vm/scripts/network-down.sh)" >&2
  exit 1
fi

echo "==> Tearing down bridge $BRIDGE_NAME / TAP $TAP_NAME"

# Remove iptables rules we added (best-effort)
if command -v iptables >/dev/null 2>&1; then
  echo "Removing iptables rules ..."
  iptables -t nat -D PREROUTING -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j DNAT --to-destination "$VM_IP:22" 2>/dev/null || true
  iptables -t nat -D POSTROUTING -s "$BRIDGE_NETWORK" ! -o "$BRIDGE_NAME" -j MASQUERADE 2>/dev/null || true
  iptables -D FORWARD -i "$BRIDGE_NAME" -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -o "$BRIDGE_NAME" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -o "$BRIDGE_NAME" -j ACCEPT 2>/dev/null || true
  iptables -D INPUT -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j ACCEPT 2>/dev/null || true
fi

# Remove TAP from bridge and delete TAP
if ip link show "$TAP_NAME" >/dev/null 2>&1; then
  echo "Deleting TAP $TAP_NAME ..."
  ip link set "$TAP_NAME" nomaster 2>/dev/null || true
  ip link set "$TAP_NAME" down 2>/dev/null || true
  ip tuntap del dev "$TAP_NAME" mode tap 2>/dev/null || ip link del "$TAP_NAME" 2>/dev/null || true
fi

# Optionally release PHYS_IF from bridge
if [ -n "${PHYS_IF:-}" ] && ip link show "$PHYS_IF" >/dev/null 2>&1; then
  if ip link show "$PHYS_IF" | grep -q "master $BRIDGE_NAME" 2>/dev/null; then
    echo "Releasing $PHYS_IF from $BRIDGE_NAME ..."
    ip link set "$PHYS_IF" nomaster 2>/dev/null || true
  fi
fi

if ip link show "$BRIDGE_NAME" >/dev/null 2>&1; then
  echo "Deleting bridge $BRIDGE_NAME ..."
  ip link set "$BRIDGE_NAME" down 2>/dev/null || true
  ip link del "$BRIDGE_NAME" 2>/dev/null || brctl delbr "$BRIDGE_NAME" 2>/dev/null || true
fi

echo "Done."
