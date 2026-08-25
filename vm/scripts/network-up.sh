#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if [ "$NETWORK_MODE" = "user" ]; then
  echo "NETWORK_MODE=user — no bridge/TAP needed (QEMU user-mode NAT)."
  echo "VM IP filtering inside the guest will NOT see real client IPs."
  echo "Apply host-side nftables/iptables if you need IP allow/deny in this mode."
  exit 0
fi

# Must be root (we're called via sudo -E)
if [ "$(id -u)" -ne 0 ]; then
  echo "network-up.sh must be run as root (use: task network:up  or  sudo bash vm/scripts/network-up.sh)" >&2
  exit 1
fi

echo "==> Creating bridge $BRIDGE_NAME and TAP $TAP_NAME (mode: $NETWORK_MODE)"

# Ensure bridge exists
if ip link show "$BRIDGE_NAME" >/dev/null 2>&1; then
  echo "Bridge $BRIDGE_NAME already exists."
else
  echo "Creating bridge $BRIDGE_NAME ..."
  ip link add name "$BRIDGE_NAME" type bridge
fi

ip link set "$BRIDGE_NAME" up

# Assign bridge IP if not already
if ! ip addr show "$BRIDGE_NAME" | grep -q "$BRIDGE_ADDR"; then
  echo "Assigning $BRIDGE_ADDR/$BRIDGE_NETMASK to $BRIDGE_NAME ..."
  ip addr add "$BRIDGE_ADDR/$BRIDGE_NETMASK" dev "$BRIDGE_NAME" 2>/dev/null || true
fi

# TAP device
if ip link show "$TAP_NAME" >/dev/null 2>&1; then
  echo "TAP $TAP_NAME already exists."
else
  echo "Creating TAP $TAP_NAME ..."
  ip tuntap add dev "$TAP_NAME" mode tap user "${SUDO_USER:-$(logname 2>/dev/null || echo root)}" 2>/dev/null || \
    ip tuntap add dev "$TAP_NAME" mode tap
fi

# Attach TAP to bridge if not already enslaved
if ! bridge link show 2>/dev/null | grep -q "$TAP_NAME" && ! ip link show "$TAP_NAME" | grep -q "master $BRIDGE_NAME"; then
  echo "Attaching $TAP_NAME to $BRIDGE_NAME ..."
  ip link set "$TAP_NAME" master "$BRIDGE_NAME" 2>/dev/null || brctl addif "$BRIDGE_NAME" "$TAP_NAME" 2>/dev/null || true
fi

ip link set "$TAP_NAME" up

# Optionally enslave physical interface (true LAN bridge)
if [ -n "${PHYS_IF:-}" ]; then
  if ip link show "$PHYS_IF" >/dev/null 2>&1; then
    # Check if it's wireless (best-effort) — bridging wifi is unsupported
    if iw dev "$PHYS_IF" info >/dev/null 2>&1; then
      echo "WARNING: PHYS_IF=$PHYS_IF looks like a wireless interface; bridging wifi is not supported." >&2
      echo "         VM will not get LAN DHCP. Use private bridge (PHYS_IF=) instead." >&2
    else
      if ! ip link show "$PHYS_IF" | grep -q "master $BRIDGE_NAME"; then
        echo "Enslaving physical interface $PHYS_IF to $BRIDGE_NAME (VM will appear on LAN) ..."
        # Bring host IP over to bridge? Simplified: just enslave. Host keeps its IP on bridge via DHCP.
        # Flush IP from PHYS_IF and rely on bridge DHCP? Safer to not flush automatically.
        # We attempt to move the default route's IP — but avoid destructive changes without explicit consent.
        echo "NOTE: For true LAN bridge, you may need to move your host IP to $BRIDGE_NAME and run DHCP there."
        echo "      Skipping automatic IP move for safety. Run manually if needed:"
        echo "        sudo ip addr flush dev $PHYS_IF && sudo dhclient $BRIDGE_NAME"
        ip link set "$PHYS_IF" master "$BRIDGE_NAME" 2>/dev/null || brctl addif "$BRIDGE_NAME" "$PHYS_IF" 2>/dev/null || true
        ip link set "$PHYS_IF" up
      else
        echo "Physical interface $PHYS_IF already enslaved to $BRIDGE_NAME."
      fi
    fi
  else
    echo "WARNING: PHYS_IF=$PHYS_IF not found, skipping." >&2
  fi
fi

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
if [ -f /proc/sys/net/ipv6/conf/all/forwarding ]; then
  echo 1 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || true
fi

# iptables forwarding + NAT for VM outbound, and DNAT for inbound SSH
# Outbound masquerade so VM can reach the internet via host
if command -v iptables >/dev/null 2>&1; then
  echo "Configuring iptables forwarding (private bridge NAT + DNAT for :$HOST_SSH_FORWARD_PORT → $VM_IP:22)"

  # Allow forwarding between bridge and the host's default outbound interface
  iptables -C FORWARD -i "$BRIDGE_NAME" -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -i "$BRIDGE_NAME" -j ACCEPT
  iptables -C FORWARD -o "$BRIDGE_NAME" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -o "$BRIDGE_NAME" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -C FORWARD -o "$BRIDGE_NAME" -j ACCEPT 2>/dev/null || iptables -I FORWARD -o "$BRIDGE_NAME" -j ACCEPT

  # Masquerade outbound from bridge network
  if ! iptables -t nat -C POSTROUTING -s "$BRIDGE_NETWORK" ! -o "$BRIDGE_NAME" -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s "$BRIDGE_NETWORK" ! -o "$BRIDGE_NAME" -j MASQUERADE
  fi

  # DNAT inbound SSH (host :2222 → VM :22) so external clients appear with real source IPs inside VM
  if ! iptables -t nat -C PREROUTING -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j DNAT --to-destination "$VM_IP:22" 2>/dev/null; then
    iptables -t nat -A PREROUTING -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j DNAT --to-destination "$VM_IP:22"
  fi

  # Also allow INPUT to host's forwarded port
  iptables -C INPUT -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j ACCEPT

  echo "iptables rules added. Current NAT table:"
  iptables -t nat -L -n -v 2>/dev/null | head -30 || true
fi

# dnsmasq is optional for DHCP; we use static IP via cloud-init, so skip unless user wants it.
# If dnsmasq is installed and not running for this bridge, we could start it, but static is simpler.

echo ""
echo "Network ready:"
ip addr show "$BRIDGE_NAME" || true
echo ""
bridge link show 2>/dev/null || brctl show 2>/dev/null || ip link show master "$BRIDGE_NAME" || true
echo ""
echo "Bridge $BRIDGE_NAME ($BRIDGE_ADDR/$BRIDGE_NETMASK) → VM $VM_IP/24 via TAP $TAP_NAME"
echo "Host forward: 0.0.0.0:$HOST_SSH_FORWARD_PORT → $VM_IP:22 (real source IPs preserved via DNAT)"
if [ -n "${PHYS_IF:-}" ]; then
  echo "Physical IF $PHYS_IF enslaved — VM appears on LAN (DHCP from LAN)."
fi
