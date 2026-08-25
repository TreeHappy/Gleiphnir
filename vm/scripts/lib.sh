#!/usr/bin/env bash
# vm/scripts/lib.sh — shared helpers for all vm/scripts/*.sh
# Usage: source "$(dirname "$0")/lib.sh"

set -euo pipefail

# Find repo root (two levels up from vm/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/sandbox.env"

# Load config/sandbox.env if it exists, exporting all vars.
if [ -f "$CONFIG_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  set +a
fi

# Defaults for any unset vars (mirror sandbox.env)
: "${VM_NAME:=gleiphnir}"
: "${VM_HOSTNAME:=gleiphnir}"
: "${UBUNTU_RELEASE:=noble}"
: "${UBUNTU_ARCH:=amd64}"
: "${UBUNTU_IMAGE_URL:=}"
: "${VM_CPUS:=4}"
: "${VM_RAM_MB:=4096}"
: "${VM_DISK_SIZE:=20G}"
: "${DATA_DISK_SIZE:=20G}"
: "${NETWORK_MODE:=bridge}"
: "${BRIDGE_NAME:=br-gleiphnir}"
: "${TAP_NAME:=tap-gleiphnir}"
: "${BRIDGE_ADDR:=192.168.100.1}"
: "${BRIDGE_NETMASK:=24}"
: "${BRIDGE_NETWORK:=192.168.100.0/24}"
: "${VM_IP:=192.168.100.10}"
: "${VM_NETMASK:=24}"
: "${VM_GATEWAY:=192.168.100.1}"
: "${VM_MAC:=}"
: "${PHYS_IF:=}"
: "${HOST_SSH_FORWARD_PORT:=2222}"
: "${ADMIN_USER:=admin}"
: "${ADMIN_SSH_KEY_PATH:=~/.ssh/gleiphnir_admin.pub}"
: "${ADMIN_SSH_PRIV_PATH:=~/.ssh/gleiphnir_admin}"
: "${IMAGES_DIR:=vm/images}"
: "${SEED_ISO:=vm/images/seed.iso}"
: "${SYSTEM_DISK:=vm/images/system.qcow2}"
: "${DATA_DISK:=vm/images/data.qcow2}"

# Expand ~ and make paths repo-relative if needed
expand_path() {
  local p="$1"
  # expand ~
  p="${p/#\~/$HOME}"
  # if relative and not already absolute, make repo-relative
  if [[ "$p" != /* ]]; then
    p="$REPO_ROOT/$p"
  fi
  echo "$p"
}

IMAGES_DIR="$(expand_path "$IMAGES_DIR")"
SEED_ISO="$(expand_path "$SEED_ISO")"
SYSTEM_DISK="$(expand_path "$SYSTEM_DISK")"
DATA_DISK="$(expand_path "$DATA_DISK")"
ADMIN_SSH_KEY_PATH="$(expand_path "$ADMIN_SSH_KEY_PATH")"
ADMIN_SSH_PRIV_PATH="$(expand_path "$ADMIN_SSH_PRIV_PATH")"

# Auto-construct image URL if empty
if [ -z "${UBUNTU_IMAGE_URL:-}" ]; then
  UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-${UBUNTU_ARCH}.img"
fi

BASE_IMAGE="$IMAGES_DIR/${UBUNTU_RELEASE}-server-cloudimg-${UBUNTU_ARCH}.img"

# Pid/monitor files
PID_FILE="$IMAGES_DIR/qemu.pid"
MONITOR_SOCK="$IMAGES_DIR/qemu-monitor.sock"
CONSOLE_LOG="$IMAGES_DIR/console.log"
MAC_FILE="$IMAGES_DIR/mac.addr"

get_vm_mac() {
  if [ -n "${VM_MAC:-}" ]; then
    echo "$VM_MAC"
    return
  fi
  if [ -f "$MAC_FILE" ]; then
    cat "$MAC_FILE"
    return
  fi
  # generate random locally-administered unicast MAC 52:54:00:xx:xx:xx
  local mac
  mac=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
  mkdir -p "$(dirname "$MAC_FILE")"
  echo "$mac" > "$MAC_FILE"
  echo "$mac"
}

vm_ssh_target() {
  # Returns "user@host -p port" args for admin SSH
  if [ "$NETWORK_MODE" = "user" ]; then
    echo "-p $HOST_SSH_FORWARD_PORT ${ADMIN_USER}@127.0.0.1"
  else
    echo "${ADMIN_USER}@${VM_IP}"
  fi
}

vm_ssh_cmd() {
  # Print base ssh command array for admin
  local key_opt=""
  if [ -f "$ADMIN_SSH_PRIV_PATH" ]; then
    key_opt="-i $ADMIN_SSH_PRIV_PATH"
  fi
  if [ "$NETWORK_MODE" = "user" ]; then
    echo "ssh $key_opt -p $HOST_SSH_FORWARD_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 ${ADMIN_USER}@127.0.0.1"
  else
    echo "ssh $key_opt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 ${ADMIN_USER}@${VM_IP}"
  fi
}

is_vm_running() {
  if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE" 2>/dev/null)" >/dev/null 2>&1; then
    return 0
  fi
  # fallback: check qemu process
  if pgrep -f "qemu.*$VM_NAME" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

require_base_image() {
  if [ ! -f "$BASE_IMAGE" ]; then
    echo "Base image not found: $BASE_IMAGE" >&2
    echo "Run: task image:download" >&2
    exit 1
  fi
}
