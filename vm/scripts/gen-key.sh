#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

mkdir -p "$(dirname "$ADMIN_SSH_KEY_PATH")"

if [ -f "$ADMIN_SSH_PRIV_PATH" ] && [ -f "$ADMIN_SSH_KEY_PATH" ]; then
  echo "Admin key already exists:"
  echo "  priv: $ADMIN_SSH_PRIV_PATH"
  echo "  pub:  $ADMIN_SSH_KEY_PATH"
  exit 0
fi

echo "Generating admin SSH keypair at $ADMIN_SSH_PRIV_PATH ..."
ssh-keygen -t ed25519 -f "$ADMIN_SSH_PRIV_PATH" -N "" -C "${ADMIN_USER}@${VM_HOSTNAME}"
chmod 600 "$ADMIN_SSH_PRIV_PATH"
chmod 644 "$ADMIN_SSH_KEY_PATH"
echo "Done."
ls -l "$ADMIN_SSH_PRIV_PATH" "$ADMIN_SSH_KEY_PATH"
