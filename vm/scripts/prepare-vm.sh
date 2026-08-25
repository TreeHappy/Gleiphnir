#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

echo "==> Preparing VM (mode: $NETWORK_MODE)"

require_base_image

mkdir -p "$IMAGES_DIR"

# ── admin SSH key ──────────────────────────────────────────────────────────
if [ ! -f "$ADMIN_SSH_KEY_PATH" ]; then
  echo "Admin key not found at $ADMIN_SSH_KEY_PATH — generating one ..."
  bash "$SCRIPT_DIR/gen-key.sh"
fi

ADMIN_SSH_PUB="$(cat "$ADMIN_SSH_KEY_PATH")"
if [ -z "$ADMIN_SSH_PUB" ]; then
  echo "Failed to read admin public key at $ADMIN_SSH_KEY_PATH" >&2
  exit 1
fi
echo "Admin key: $ADMIN_SSH_KEY_PATH"
echo "Admin user: $ADMIN_USER"

# ── MAC ────────────────────────────────────────────────────────────────────
VM_MAC_ADDR="$(get_vm_mac)"
echo "VM MAC: $VM_MAC_ADDR"

# ── disks ──────────────────────────────────────────────────────────────────
# System disk: qcow2 overlay on top of base cloud image (so base stays pristine)
if [ ! -f "$SYSTEM_DISK" ]; then
  echo "Creating system overlay disk $SYSTEM_DISK (backing: $BASE_IMAGE, size: $VM_DISK_SIZE) ..."
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$SYSTEM_DISK" "$VM_DISK_SIZE"
else
  echo "System disk already exists: $SYSTEM_DISK"
  qemu-img info "$SYSTEM_DISK" | head -5
fi

if [ ! -f "$DATA_DISK" ]; then
  echo "Creating data disk $DATA_DISK ($DATA_DISK_SIZE) ..."
  qemu-img create -f qcow2 "$DATA_DISK" "$DATA_DISK_SIZE"
else
  echo "Data disk already exists: $DATA_DISK"
  qemu-img info "$DATA_DISK" | head -5
fi

# ── cloud-init ─────────────────────────────────────────────────────────────
CLOUD_INIT_DIR="$REPO_ROOT/vm/cloud-init"
TMPDIR_CLOUD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CLOUD"' EXIT

echo "Generating cloud-init seed ISO ..."

# Prepare user-data from template (simple substitution)
TEMPLATE="$CLOUD_INIT_DIR/user-data.yaml.tpl"
if [ ! -f "$TEMPLATE" ]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi

cp "$TEMPLATE" "$TMPDIR_CLOUD/user-data"

# Replace placeholders — including large file inlines (indented literal blocks)
python3 <<PY
import pathlib

tmpdir = "$TMPDIR_CLOUD"
repo = "$REPO_ROOT"
admin_key_path = "$ADMIN_SSH_KEY_PATH"
admin_user = "$ADMIN_USER"
hostname = "$VM_HOSTNAME"
container_image = "$CONTAINER_IMAGE"

# Map placeholder token -> source file path
sources = {
  "__NFTABLES_CONTENT__": f"{repo}/vm/guest/nftables-sandbox.nft",
  "__SANDBOX_SHELL_CONTENT__": f"{repo}/vm/guest/bin/sandbox-shell",
  "__SANDBOX_USER_CONTENT__": f"{repo}/vm/guest/bin/sandbox-user",
  "__SANDBOX_FIREWALL_CONTENT__": f"{repo}/vm/guest/bin/sandbox-firewall",
  "__BUILD_CONTAINER_CONTENT__": f"{repo}/vm/guest/lib/build-container.sh",
  "__CONTAINERFILE_CONTENT__": f"{repo}/container/Containerfile",
  "__ENTRYPOINT_CONTENT__": f"{repo}/container/entrypoint.sh",
  "__MISE_TOML_CONTENT__": f"{repo}/container/files/mise.toml",
  "__BASHRC_CONTENT__": f"{repo}/container/files/bashrc",
}

p = pathlib.Path(f"{tmpdir}/user-data")
text = p.read_text()

# Simple scalar replacements
pub = pathlib.Path(admin_key_path).read_text().strip()
text = text.replace("__ADMIN_SSH_PUB__", pub)
text = text.replace("__ADMIN_USER__", admin_user)
text = text.replace("__VM_HOSTNAME__", hostname)
text = text.replace("__CONTAINER_IMAGE__", container_image)

# For each file placeholder, replace the lone token line with indented file content
# Template has a line containing exactly the token (e.g. "__NFTABLES_CONTENT__")
# We replace that line with the file's lines each indented by 6 spaces (YAML literal block).
for token, src_path in sources.items():
  src = pathlib.Path(src_path)
  if not src.exists():
    print(f"WARNING: source not found for {token}: {src_path}")
    content_indented = "      # (missing source: " + src_path + ")\n"
  else:
    raw = src.read_text()
    # Ensure file ends without extra trailing blank that could break YAML? Keep as-is.
    lines = raw.splitlines()
    indented = "\n".join("      " + l for l in lines)
    # Ensure there's a trailing newline after the block
    content_indented = indented + "\n"
  # token appears on its own line in template
  if token in text:
    # Replace the line that contains only the token (with optional surrounding whitespace)
    # We do a simple replace of token string; the indentation before token is already 0, we want 6-space indented content.
    # The template line is e.g. "__NFTABLES_CONTENT__\n" at column 0, after "    content: |\n"
    # Replace token with indented content; if token not found as line, fallback to string replace
    text = text.replace(token, content_indented.rstrip("\n"))
  else:
    print(f"WARNING: token {token} not found in template")

p.write_text(text)
print("user-data templated with inlined guest/container sources")
PY

# network-config depends on NETWORK_MODE
NETWORK_CONFIG_SRC=""
if [ "$NETWORK_MODE" = "user" ]; then
  NETWORK_CONFIG_SRC="$CLOUD_INIT_DIR/network-config.user.yaml"
else
  NETWORK_CONFIG_SRC="$CLOUD_INIT_DIR/network-config.bridge.yaml"
fi

if [ -f "$NETWORK_CONFIG_SRC" ]; then
  cp "$NETWORK_CONFIG_SRC" "$TMPDIR_CLOUD/network-config"
  # template VM_IP etc into network-config
  python3 <<PY
import pathlib
p = pathlib.Path("$TMPDIR_CLOUD/network-config")
text = p.read_text()
text = text.replace("__VM_IP__", "$VM_IP")
text = text.replace("__VM_NETMASK__", "$VM_NETMASK")
text = text.replace("__VM_GATEWAY__", "$VM_GATEWAY")
text = text.replace("__VM_MAC__", "$VM_MAC_ADDR")
p.write_text(text)
PY
  echo "Using network-config: $NETWORK_CONFIG_SRC"
else
  echo "WARNING: network-config source not found: $NETWORK_CONFIG_SRC — using DHCP fallback" >&2
  cat > "$TMPDIR_CLOUD/network-config" <<'YAML'
version: 2
ethernets:
  vmnet:
    match: {name: "en*"}
    dhcp4: true
YAML
fi

cp "$CLOUD_INIT_DIR/meta-data" "$TMPDIR_CLOUD/meta-data" 2>/dev/null || echo "instance-id: $VM_NAME" > "$TMPDIR_CLOUD/meta-data"

# Inject container sources into cloud-init? Instead, cloud-init runcmd will copy from nocloud seed?
# Simpler: we place container/ files into an extra ISO or let cloud-init fetch them via write_files.
# Our user-data template already contains guest scripts inline, so no extra step needed.

echo "--- user-data preview (first 80 lines) ---"
head -80 "$TMPDIR_CLOUD/user-data" || true
echo "--- network-config ---"
cat "$TMPDIR_CLOUD/network-config" || true

# Build seed ISO via cloud-localds (preferred) or genisoimage fallback
if command -v cloud-localds >/dev/null 2>&1; then
  echo "Building seed ISO with cloud-localds ..."
  cloud-localds "$SEED_ISO" "$TMPDIR_CLOUD/user-data" "$TMPDIR_CLOUD/meta-data" --network-config="$TMPDIR_CLOUD/network-config" --verbose
elif command -v genisoimage >/dev/null 2>&1; then
  echo "cloud-localds not found, using genisoimage fallback ..."
  genisoimage -output "$SEED_ISO" -volid cidata -joliet -rock "$TMPDIR_CLOUD/user-data" "$TMPDIR_CLOUD/meta-data" 2>&1 | head -20
  # genisoimage needs specific naming; cloud-init expects files named user-data/meta-data at ISO root
  # The above creates an ISO with those files, but we need to ensure correct layout via mkisofs options
  # Simpler: try cloud-localds error hint
  if [ ! -f "$SEED_ISO" ]; then
    echo "Failed to build seed ISO with genisoimage fallback. Please install cloud-image-utils (provides cloud-localds)." >&2
    exit 1
  fi
else
  echo "Need cloud-localds (from cloud-image-utils) or genisoimage to build seed ISO" >&2
  echo "  Ubuntu: sudo apt-get install cloud-image-utils" >&2
  exit 1
fi

ls -lh "$SEED_ISO"
echo ""
echo "VM preparation complete. Disks:"
ls -lh "$IMAGES_DIR/"
echo ""
echo "Next: task vm:start  (or task up for full bring-up)"
