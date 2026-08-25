#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

all=false
if [ "${1:-}" = "--all" ]; then all=true; fi

if is_vm_running; then
  echo "VM is running — stop it first: task vm:stop" >&2
  exit 1
fi

echo "Cleaning VM artifacts in $IMAGES_DIR (all=$all) ..."
set -x
rm -f "$SEED_ISO"
rm -f "$SYSTEM_DISK"
rm -f "$DATA_DISK"
rm -f "$PID_FILE" "$MONITOR_SOCK" "$CONSOLE_LOG"
rm -f "$IMAGES_DIR/mac.addr" 2>/dev/null || true
set +x

if [ "$all" = true ]; then
  echo "Removing base image as well (--all)"
  rm -f "$BASE_IMAGE"
fi

echo "Done. Remaining in $IMAGES_DIR:"
ls -lh "$IMAGES_DIR" 2>/dev/null || echo "(empty)"
