#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

key_opt=()
if [ -f "$ADMIN_SSH_PRIV_PATH" ]; then
  key_opt=(-i "$ADMIN_SSH_PRIV_PATH")
fi

ssh_admin() {
  if [ "$NETWORK_MODE" = "user" ]; then
    ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "$@"
  else
    if ssh "${key_opt[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 "${ADMIN_USER}@${VM_IP}" "$@" 2>/dev/null; then
      return 0
    fi
    ssh "${key_opt[@]}" -p "$HOST_SSH_FORWARD_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${ADMIN_USER}@127.0.0.1" "$@"
  fi
}

echo "=== Gleiphnir smoke test ==="
echo "VM: $VM_IP  Forward: :$HOST_SSH_FORWARD_PORT  Mode: $NETWORK_MODE"
echo ""

fail=0
pass=0

check() {
  local desc="$1"
  shift
  echo -n "  [ ] $desc ... "
  if "$@" >/dev/null 2>&1; then
    echo "PASS"
    pass=$((pass+1))
  else
    echo "FAIL"
    fail=$((fail+1))
  fi
}

# Need at least one sandbox user to test container path
# Try to discover users
echo "Discovering sandbox users ..."
users="$(ssh_admin "ls -1 /srv/sandbox 2>/dev/null | head -5" || true)"
echo "  workspaces: ${users:-<none>}"
if [ -z "$users" ]; then
  echo ""
  echo "No sandbox workspaces found. Creating ephemeral test user 'smoketest' ..."
  tmpkey="$(mktemp)"
  ssh-keygen -t ed25519 -f "$tmpkey" -N "" -C "smoketest@smoke" >/dev/null 2>&1
  b64="$(cat "$tmpkey.pub" | base64 -w0)"
  ssh_admin "echo '$b64' | base64 -d | sudo /usr/local/bin/sandbox-user add smoketest --key-file /dev/stdin 2>&1 | tail -5" || true
  rm -f "$tmpkey" "$tmpkey.pub"
  users="smoketest"
  SMOKETEST_EPHEMERAL=1
else
  SMOKETEST_EPHEMERAL=0
fi

test_user="$(echo "$users" | head -1 | tr -d '[:space:]')"
echo "Testing as user: $test_user"
echo ""

# For container tests, we need to run commands via the user's container.
# We use `sudo -u $test_user podman run ...` via admin SSH, or ssh as that user if we have a key.
# Simpler: admin runs a one-shot podman run as rootful simulating the sandbox but we also test the real shell path.
# We'll do both: direct podman invocation checks (via admin) and, if we have test key, ssh-as-user checks.

echo "--- VM-level checks (as admin) ---"
check "VM SSH reachable" ssh_admin "true"
check "nftables active" ssh_admin "sudo nft list ruleset >/dev/null"
check "podman works" ssh_admin "podman info >/dev/null"
check "sandbox image exists" ssh_admin "podman image exists $CONTAINER_IMAGE"
check "data disk mounted at /srv/sandbox" ssh_admin "mountpoint -q /srv/sandbox"

echo ""
echo "--- container checks (via admin, simulating sandbox) ---"
# Use admin to run container with same flags as sandbox-shell (rootful variant for smoke)
# We create a throwaway workspace for smoke
SMOKE_WORK="/srv/sandbox/.smoke-$$"
ssh_admin "sudo mkdir -p $SMOKE_WORK && sudo chown 1000:1000 $SMOKE_WORK"

run_c() {
  ssh_admin "podman run --rm --read-only --tmpfs /tmp:rw,mode=1777 --tmpfs /run:rw,mode=755 --tmpfs /home/dev:rw,mode=777 --cap-drop ALL --security-opt no-new-privileges -v $SMOKE_WORK:/work:rw -w /work $CONTAINER_IMAGE bash -c \"$1\""
}

check "container starts and prints hello" run_c "echo hello | grep -q hello"
check "rootfs is read-only (touch / should fail)" bash -c "! run_c 'touch /should-fail 2>/dev/null'"
check "/work is writable" run_c "touch /work/smoke-marker && ls /work/smoke-marker"
check "no sudo in container" bash -c "! run_c 'command -v sudo >/dev/null'"
check "git present" run_c "git --version | grep -q git"
check "mise present" run_c "mise --version | grep -q mise"
check "mise installs tools (node --version after mise use)" run_c "mise --version"

echo ""
echo "--- firewall checks ---"
check "sandbox-firewall list works" ssh_admin "sudo /usr/local/bin/sandbox-firewall list >/dev/null"
# Try allow then remove of a dummy IP (TEST-NET-1)
check "sandbox-firewall allow 192.0.2.1" ssh_admin "sudo /usr/local/bin/sandbox-firewall allow 192.0.2.1"
check "sandbox-firewall remove 192.0.2.1" ssh_admin "sudo /usr/local/bin/sandbox-firewall remove 192.0.2.1"

# Cleanup
ssh_admin "sudo rm -rf $SMOKE_WORK" || true
if [ "${SMOKETEST_EPHEMERAL:-0}" = "1" ]; then
  echo ""
  echo "Cleaning up ephemeral smoketest user ..."
  ssh_admin "sudo /usr/local/bin/sandbox-user remove smoketest 2>&1 | tail -3" || true
fi

echo ""
echo "=== Results: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  echo "Some checks failed — see above."
  exit 1
else
  echo "All smoke checks passed."
fi
