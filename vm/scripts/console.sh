#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if [ ! -f "$CONSOLE_LOG" ]; then
  echo "Console log not found: $CONSOLE_LOG" >&2
  echo "Is the VM running? task vm:info" >&2
  exit 1
fi

echo "==> VM console log (tail -f). VM serial is also available via QEMU monitor."
echo "    Log: $CONSOLE_LOG"
echo "    Press Ctrl-C to stop tailing (VM keeps running)."
echo ""
tail -f "$CONSOLE_LOG"
