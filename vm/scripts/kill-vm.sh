#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

echo "Force-killing VM $VM_NAME ..."
pids="$(pgrep -f "qemu.*$VM_NAME" || true)"
if [ -z "$pids" ] && [ -f "$PID_FILE" ]; then
  pids="$(cat "$PID_FILE" 2>/dev/null || true)"
fi
if [ -z "$pids" ]; then
  echo "No VM process found."
  rm -f "$PID_FILE" "$MONITOR_SOCK"
  exit 0
fi
echo "Killing PIDs: $pids"
kill -9 $pids 2>/dev/null || sudo kill -9 $pids 2>/dev/null || true
rm -f "$PID_FILE" "$MONITOR_SOCK"
echo "Done."
