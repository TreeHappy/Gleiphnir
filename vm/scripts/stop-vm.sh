#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if [ -S "$MONITOR_SOCK" ]; then
  echo "Asking QEMU to quit via monitor $MONITOR_SOCK ..."
  if command -v socat >/dev/null 2>&1; then
    echo "quit" | socat - "UNIX-CONNECT:$MONITOR_SOCK" 2>/dev/null || true
  elif command -v nc >/dev/null 2>&1; then
    echo "quit" | nc -U "$MONITOR_SOCK" 2>/dev/null || true
  else
    # fallback: use qemu monitor via netcat-like bash
    echo "quit" | sudo socat - "UNIX-CONNECT:$MONITOR_SOCK" 2>/dev/null || true
  fi
  sleep 2
fi

if [ -f "$PID_FILE" ]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
  if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
    echo "Sending SIGTERM to QEMU PID $pid ..."
    kill "$pid" 2>/dev/null || sudo kill "$pid" 2>/dev/null || true
    # wait up to 10s
    for i in $(seq 1 10); do
      if ! ps -p "$pid" >/dev/null 2>&1; then break; fi
      sleep 1
    done
    if ps -p "$pid" >/dev/null 2>&1; then
      echo "PID $pid still alive, use task vm:kill to force." >&2
    else
      echo "VM stopped."
      rm -f "$PID_FILE" "$MONITOR_SOCK"
    fi
  else
    echo "PID file exists but no process at $pid — cleaning up."
    rm -f "$PID_FILE" "$MONITOR_SOCK"
  fi
else
  # try pgrep fallback
  pids="$(pgrep -f "qemu.*$VM_NAME" || true)"
  if [ -n "$pids" ]; then
    echo "Found QEMU processes for $VM_NAME: $pids"
    echo "Killing ..."
    kill $pids 2>/dev/null || sudo kill $pids 2>/dev/null || true
    sleep 2
    if pgrep -f "qemu.*$VM_NAME" >/dev/null 2>&1; then
      echo "Still running — use task vm:kill" >&2
    else
      echo "VM stopped."
    fi
    rm -f "$MONITOR_SOCK"
  else
    echo "No running VM found."
  fi
fi
