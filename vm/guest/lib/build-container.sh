#!/usr/bin/env bash
# /usr/local/lib/sandbox/build-container.sh — builds localhost/sandbox:latest
# Runs inside the VM. Expects container sources at /opt/sandbox/container/
# (populated by cloud-init) or falls back to fetching from /opt/sandbox/container-src.
# After a successful build it warms the SHARED mise volume (sandbox-mise) so
# toolchains are downloaded once for all sandbox users.
set -euo pipefail

CONTAINER_IMAGE="${CONTAINER_IMAGE:-localhost/sandbox:latest}"
SRC_DIR="/opt/sandbox/container"
FALLBACK_TMP="/tmp/sandbox-container-src"
MISE_VOLUME="sandbox-mise"

warm_mise_volume() {
  echo "==> Warming shared mise volume '$MISE_VOLUME' ..."
  podman volume inspect "$MISE_VOLUME" >/dev/null 2>&1 || podman volume create "$MISE_VOLUME" >/dev/null
  podman run --rm --read-only \
    --tmpfs /tmp:rw,size=512m,mode=1777 \
    --tmpfs /home/dev:rw,size=256m,mode=777 \
    --cap-drop ALL --security-opt no-new-privileges \
    -v "${MISE_VOLUME}:/opt/mise-shared:rw,U" \
    -e HOME=/home/dev -e USER=dev \
    -e MISE_DATA_DIR=/opt/mise-shared/data \
    -e MISE_STATE_DIR=/opt/mise-shared/state \
    -e MISE_CACHE_DIR=/opt/mise-shared/cache \
    -e MISE_CONFIG_DIR=/work/.mise/config \
    --entrypoint /bin/bash "$CONTAINER_IMAGE" -c '
      set -e
      mkdir -p /opt/mise-shared/data /opt/mise-shared/state /opt/mise-shared/cache /work/.mise/config
      mise trust --all >/dev/null 2>&1 || true
      export MISE_GLOBAL_CONFIG_FILE=/etc/sandbox/mise.toml
      echo "  mise install (first warm-up downloads; later runs are no-ops) ..."
      mise install --yes || echo "  [warmup] some tools failed — they will install lazily on first use"
      mise reshim >/dev/null 2>&1 || true
      echo "  warmed tools:" ; ls /opt/mise-shared/data/installs 2>/dev/null | sed "s/^/    /" || true
    ' || echo "[warmup] failed — containers will bootstrap lazily instead"
}

build_image() {
  local ctx="$1"
  echo "Building $CONTAINER_IMAGE from $ctx ..."
  podman build -t "$CONTAINER_IMAGE" -f "$SRC_DIR/Containerfile" "$ctx"
  echo "Built $CONTAINER_IMAGE"
  podman images | grep -E "REPOSITORY|sandbox" || podman images | head -20
  warm_mise_volume
  exit 0
}

if [ -f "$SRC_DIR/Containerfile" ]; then
  build_image "$SRC_DIR"
fi

if [ ! -f "$SRC_DIR/files/mise.toml" ] && [ -f "$FALLBACK_TMP/Containerfile" ]; then
  SRC_DIR="$FALLBACK_TMP"
  build_image "$FALLBACK_TMP"
fi

echo "No container sources found. Expected $SRC_DIR/Containerfile" >&2
echo "Cloud-init may not have populated /opt/sandbox/container — check /var/log/cloud-init.log" >&2
exit 1
