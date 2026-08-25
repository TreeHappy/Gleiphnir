#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

echo "=== VM info: $VM_NAME ==="
echo "Mode:          $NETWORK_MODE"
echo "Hostname:      $VM_HOSTNAME"
echo "Resources:     ${VM_CPUS} vCPU / ${VM_RAM_MB}MB"
echo "Bridge:        $BRIDGE_NAME ($BRIDGE_ADDR/$BRIDGE_NETMASK)  TAP: $TAP_NAME"
echo "VM IP:         $VM_IP/24  GW: $VM_GATEWAY  MAC: $(get_vm_mac)"
echo "Host forward:  127.0.0.1:$HOST_SSH_FORWARD_PORT → $VM_IP:22"
echo "Admin:         $ADMIN_USER  key: $ADMIN_SSH_KEY_PATH"
echo ""

echo "--- Running ---"
if is_vm_running; then
  echo "VM appears RUNNING"
  if [ -f "$PID_FILE" ]; then echo "  PID file: $PID_FILE → $(cat "$PID_FILE")"; fi
  pgrep -a -f "qemu.*$VM_NAME" 2>/dev/null || ps aux | grep -i qemu | grep -v grep || true
else
  echo "VM appears STOPPED"
  if [ -f "$PID_FILE" ]; then echo "  stale PID file: $PID_FILE ($(cat "$PID_FILE" 2>/dev/null))"; fi
fi
echo ""

echo "--- Disks ---"
for f in "$BASE_IMAGE" "$SYSTEM_DISK" "$DATA_DISK" "$SEED_ISO"; do
  if [ -f "$f" ]; then ls -lh "$f"; qemu-img info "$f" 2>/dev/null | grep -E "virtual size|disk size|backing" | sed 's/^/  /'; echo ""; else echo "MISSING: $f"; echo ""; fi
done

echo "--- Networking ---"
bash "$SCRIPT_DIR/network-status.sh" 2>&1 || true

echo "--- Console log (last 20) ---"
tail -20 "$CONSOLE_LOG" 2>/dev/null || echo "(no console log yet)"
