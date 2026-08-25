#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if is_vm_running; then
  echo "VM already appears to be running (pid file $PID_FILE or matching process)." >&2
  echo "Use: task vm:info / task vm:stop"
  exit 1
fi

require_base_image

if [ ! -f "$SYSTEM_DISK" ] || [ ! -f "$DATA_DISK" ] || [ ! -f "$SEED_ISO" ]; then
  echo "Disks or seed ISO missing. Running prepare step first ..."
  bash "$SCRIPT_DIR/prepare-vm.sh"
fi

VM_MAC_ADDR="$(get_vm_mac)"

# ── ensure networking ──────────────────────────────────────────────────────
if [ "$NETWORK_MODE" = "bridge" ]; then
  if ! ip link show "$BRIDGE_NAME" >/dev/null 2>&1; then
    echo "Bridge $BRIDGE_NAME not found — creating (requires sudo) ..."
    if [ "$(id -u)" -eq 0 ]; then
      bash "$SCRIPT_DIR/network-up.sh"
    else
      sudo -E bash "$SCRIPT_DIR/network-up.sh"
    fi
  else
    echo "Bridge $BRIDGE_NAME exists."
  fi
  # ensure iptables DNAT is present after reboot
  if command -v iptables >/dev/null 2>&1 && ! sudo iptables -t nat -C PREROUTING -p tcp --dport "$HOST_SSH_FORWARD_PORT" -j DNAT --to-destination "$VM_IP:22" 2>/dev/null; then
    echo "Re-adding iptables DNAT rule ..."
    sudo -E bash "$SCRIPT_DIR/network-up.sh" 2>&1 | tail -5 || true
  fi
fi

# ── QEMU args ──────────────────────────────────────────────────────────────
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
  QEMU_BIN="qemu-system-x86_64"
fi

KVM_ARGS=""
if [ -c /dev/kvm ] && [ -r /dev/kvm ]; then
  KVM_ARGS="-enable-kvm -cpu host"
else
  echo "WARNING: /dev/kvm not available — VM will run in slow TCG mode." >&2
  KVM_ARGS="-cpu qemu64"
fi

# Network args per mode
NET_ARGS=()
if [ "$NETWORK_MODE" = "user" ]; then
  NET_ARGS=(-netdev "user,id=net0,hostfwd=tcp::${HOST_SSH_FORWARD_PORT}-:22,hostname=${VM_HOSTNAME}" -device "virtio-net-pci,netdev=net0,mac=${VM_MAC_ADDR}")
else
  NET_ARGS=(-netdev "tap,id=net0,ifname=${TAP_NAME},script=no,downscript=no" -device "virtio-net-pci,netdev=net0,mac=${VM_MAC_ADDR}")
fi

mkdir -p "$IMAGES_DIR"

# Remove stale monitor socket
rm -f "$MONITOR_SOCK"

# Build QEMU command
# shellcheck disable=SC2206
EXTRA_ARGS=(${QEMU_EXTRA_ARGS:-})

echo "==> Starting VM $VM_NAME"
echo "  Mode:     $NETWORK_MODE"
echo "  CPUs:     $VM_CPUS  RAM: ${VM_RAM_MB}MB"
echo "  System:   $SYSTEM_DISK"
echo "  Data:     $DATA_DISK"
echo "  Seed:     $SEED_ISO"
echo "  MAC:      $VM_MAC_ADDR"
if [ "$NETWORK_MODE" = "bridge" ]; then
  echo "  Net:      TAP $TAP_NAME → bridge $BRIDGE_NAME → VM $VM_IP (host :$HOST_SSH_FORWARD_PORT → VM :22)"
else
  echo "  Net:      user-mode NAT (host 127.0.0.1:$HOST_SSH_FORWARD_PORT → VM :22)"
fi
echo "  QEMU:     $QEMU_BIN $KVM_ARGS"
echo "  Monitor:  $MONITOR_SOCK"
echo "  Console:  $CONSOLE_LOG"
echo ""

set -x
"$QEMU_BIN" \
  -name "$VM_NAME" \
  $KVM_ARGS \
  -smp "$VM_CPUS" \
  -m "$VM_RAM_MB" \
  -drive "file=${SYSTEM_DISK},if=virtio,format=qcow2" \
  -drive "file=${DATA_DISK},if=virtio,format=qcow2" \
  -drive "file=${SEED_ISO},if=virtio,format=raw,readonly=on" \
  -boot order=c \
  "${NET_ARGS[@]}" \
  -display none \
  -daemonize \
  -pidfile "$PID_FILE" \
  -serial "file:${CONSOLE_LOG}" \
  -monitor "unix:${MONITOR_SOCK},server,nowait" \
  "${EXTRA_ARGS[@]}"
set +x

echo ""
# Wait briefly for pid file
for i in 1 2 3 4 5; do
  if [ -f "$PID_FILE" ]; then break; fi
  sleep 0.5
done

if [ -f "$PID_FILE" ]; then
  echo "VM started with PID $(cat "$PID_FILE")"
else
  # daemonize may have used different pid path; check pgrep
  if pgrep -f "qemu.*$VM_NAME" >/dev/null; then
    echo "VM started (pid file not found but process exists)"
    pgrep -f "qemu.*$VM_NAME" | head -5
  else
    echo "VM start may have failed — check $CONSOLE_LOG" >&2
    tail -50 "$CONSOLE_LOG" 2>/dev/null || true
    exit 1
  fi
fi

echo ""
echo "Console log tail:"
tail -20 "$CONSOLE_LOG" 2>/dev/null || echo "(no console output yet)"
echo ""
if [ "$NETWORK_MODE" = "bridge" ]; then
  echo "VM should be at $VM_IP (via bridge $BRIDGE_NAME)."
  echo "Host forward: ssh -p $HOST_SSH_FORWARD_PORT ${ADMIN_USER}@127.0.0.1  (or ssh ${ADMIN_USER}@${VM_IP})"
else
  echo "VM SSH via host forward only: ssh -p $HOST_SSH_FORWARD_PORT ${ADMIN_USER}@127.0.0.1"
fi
echo "Wait for boot: task vm:ssh:wait  (or task vm:console to watch boot)"
