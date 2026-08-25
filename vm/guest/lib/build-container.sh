#!/usr/bin/env bash
# /usr/local/lib/sandbox/build-container.sh — builds localhost/sandbox:latest
# Runs inside the VM. Expects container sources at /opt/sandbox/container/
# (populated by cloud-init) or falls back to fetching from /opt/sandbox/container-src.
set -euo pipefail

CONTAINER_IMAGE="${CONTAINER_IMAGE:-localhost/sandbox:latest}"
SRC_DIR="/opt/sandbox/container"
FALLBACK_TMP="/tmp/sandbox-container-src"

if [ -d "$SRC_DIR/Containerfile" ] || [ -f "$SRC_DIR/Containerfile" ]; then
  echo "Building $CONTAINER_IMAGE from $SRC_DIR ..."
  podman build -t "$CONTAINER_IMAGE" -f "$SRC_DIR/Containerfile" "$SRC_DIR"
  echo "Built $CONTAINER_IMAGE"
  podman images | grep -E "REPOSITORY|sandbox" || podman images | head -20
  exit 0
fi

if [ -f "$SRC_DIR/files/mise.toml" ]; then
  # Containerfile may be at $SRC_DIR directly
  if [ -f "$SRC_DIR/Containerfile" ]; then
    podman build -t "$CONTAINER_IMAGE" -f "$SRC_DIR/Containerfile" "$SRC_DIR"
  else
    echo "No Containerfile at $SRC_DIR/Containerfile" >&2
    exit 1
  fi
  exit 0
fi

# Last resort: try to reconstitute from embedded sources if any
echo "Container sources not found at $SRC_DIR — checking $FALLBACK_TMP ..." >&2
if [ -f "$FALLBACK_TMP/Containerfile" ]; then
  podman build -t "$CONTAINER_IMAGE" -f "$FALLBACK_TMP/Containerfile" "$FALLBACK_TMP"
  exit 0
fi

echo "No container sources found. Expected $SRC_DIR/Containerfile" >&2
echo "Cloud-init may not have populated /opt/sandbox/container — check /var/log/cloud-init.log" >&2
exit 1
