#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

mkdir -p "$IMAGES_DIR"

if [ -f "$BASE_IMAGE" ]; then
  echo "Base image already exists: $BASE_IMAGE"
  echo "Remove it first to re-download, or run: task image:info"
  qemu-img info "$BASE_IMAGE" 2>/dev/null || true
  exit 0
fi

echo "Downloading Ubuntu cloud image:"
echo "  URL:  $UBUNTU_IMAGE_URL"
echo "  Dest: $BASE_IMAGE"
echo ""

if command -v curl >/dev/null 2>&1; then
  curl -L --progress-bar -o "$BASE_IMAGE" "$UBUNTU_IMAGE_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$BASE_IMAGE" "$UBUNTU_IMAGE_URL"
else
  echo "Need curl or wget" >&2
  exit 1
fi

echo ""
echo "Verifying image:"
qemu-img info "$BASE_IMAGE"
ls -lh "$BASE_IMAGE"
echo ""
echo "Done. Next: task vm:prepare"
