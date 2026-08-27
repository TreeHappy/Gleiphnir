---
id: 002
title: Replace vm/scripts/*.ps1 (pwsh) with bash (strict, otel-cli, python, mise kept)
status: todo
priority: high
depends_on: [001]
estimate: "2-3d"
branch: chore/tasks-002-pwsh-to-bash
---

## Goal / Non-Goals

- **Goal:** Host orchestration `vm/scripts/*.ps1` (`pwsh 7+` `README.md:112`) → `bash 5+` `set -euo pipefail` + `shellcheck`, single Linux `KVM/bridge` path after `001`. Keep `otel-cli` spans, keep `python3` (`template_userdata.py`, `build_seed_iso.py`), keep `mise run` as alias to `bash`. No change to guest `vm/guest/bin/*` (already bash `sandbox-proxy:1`, `sandbox-secrets:1`, `sandbox-shell:1`) or container `pwsh` (`vm/guest/bin/sandbox-shell:126` `SHELL=/usr/local/bin/sandbox-pwsh`).
- **Non-Goals:** No proxy/secrets redesign (`003`/`004`), no Firecracker/binary impl (`005`), no guest/container `pwsh` removal.

## Current state (file:line refs)

- `vm/scripts/lib.ps1:1-275` central helpers dot-sourced everywhere (`$ScriptDir/$RepoRoot/$ConfigFile` `vm/scripts/lib.ps1:6-8`, env file parse `vm/scripts/lib.ps1:13-26` `KEY=VALUE` quoted strip, `Set-Default` `vm/scripts/lib.ps1:29-84`, `Expand-RepoPath` `vm/scripts/lib.ps1:89-98`, derived `BASE_IMAGE/PID_FILE/CONSOLE_LOG/MONITOR_SOCK` `vm/scripts/lib.ps1:112-116`, `Get-VmMac` `vm/scripts/lib.ps1:138-145`, `Get-QemuPids` `vm/scripts/lib.ps1:148-177`, `Require-BaseImage` `vm/scripts/lib.ps1:183-187`, `Invoke-AdminSsh` `vm/scripts/lib.ps1:201-223`, `Invoke-AdminSshWithFallback` `vm/scripts/lib.ps1:225-240`, `Start-OtelSpan/End-OtelSpan/Invoke-WithSpan` `vm/scripts/lib.ps1:246-275`). Called as `. (Join-Path $PSScriptRoot 'lib.ps1')` in each `*.ps1`.
- `vm/scripts/start-vm.ps1:1-189`, `prepare-vm.ps1:1-168` (`qemu-img create` `vm/scripts/prepare-vm.ps1:35-51`, `template_userdata.py` `vm/scripts/prepare-vm.ps1:68-69`, `network-config` `vm/scripts/prepare-vm.ps1:73-84`, ISO fallback `vm/scripts/prepare-vm.ps1:109-152`), `network-up.ps1:1-137` (`ip link/addr/tuntap + iptables DNAT/MASQUERADE` `vm/scripts/network-up.ps1:26-116`), `network-down.ps1:1-69`, `network-status.ps1`, `stop-vm.ps1:7-30` `Send-MonitorQuit` (`TcpClient`/`UnixDomainSocketEndPoint`), `kill-vm.ps1`, `vm-info.ps1`, `deps.ps1:1-91` (`Check-Bin` `vm/scripts/deps.ps1:8-18`), `install-deps.ps1`, `download-image.ps1`, `gen-key.ps1`, `manage-policy.ps1:35-36` `Escape-ShellArg`, `secrets.ps1:27-32` age checks, `sbom.ps1`, `ssh-admin.ps1`, `wait-ssh.ps1`, `smoke-test.ps1` etc. — all `pwsh`.
- Caller: `mise.toml:30` `pwsh -NoProfile -File '{{ config_root }}/vm/scripts/deps.ps1'` repeated ~30 tasks `mise.toml:28-311` via `[tools] powershell = "latest"` `mise.toml:9`+`opencode` `mise.toml:7`. Network tasks already `sudo -E {{ which('pwsh') }}` `mise.toml:52,57`.

## Decisions confirmed

1. **Strict bash:** Yes — every `*.sh` starts `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'` + `shellcheck` clean. `ErrorActionPreference=Stop` `vm/scripts/lib.ps1:4` parity.
2. **OTel:** Yes — keep `otel-cli` (`mise.toml:11` `github:equinix-labs/otel-cli`) wrapping each script: `start_span gleiphnir.start_vm` `vm/scripts/lib.ps1:246-275` → bash `otel_cli_span()` that no-ops if `OTEL_EXPORTER_OTLP_ENDPOINT` empty `config/sandbox.env:88` or `otel-cli` missing. `OBSERVABILITY_ENABLED` `config/sandbox.env:72` gates `mise.toml:229-233` `obs:start`.
3. **Python:** Keep for now — `python3` `vm/scripts/template_userdata.py:14-46` (inlines 20 `__TOKEN__` files `vm/scripts/template_userdata.py:17-45` into `user-data.yaml.tpl:1-287`) + `vm/scripts/build_seed_iso.py:19` `pycdlib` ISO. No `cloud-localds` rewrite yet; `prepare-vm.sh` keeps fallback `cloud-localds→genisoimage→pycdlib` `vm/scripts/prepare-vm.ps1:109-152`.
4. **Mise:** Keep — `mise.toml` tasks stay but `pwsh -File` → `bash`, users still `mise run up`/`gleiphnir` alias `vm/files/gleiphnir`.

## Proposed change

**New `vm/scripts/lib.sh` (replaces `lib.ps1`):**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/sandbox.env"
# source config/sandbox.env like mise: set -a; source; set +a, then defaults
set -a; [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"; set +a
: "${VM_NAME:=gleiphnir}"      # mirror lib.ps1:36-80 defaults + config/sandbox.env:6-66
: "${VM_CPUS:=4}" "${VM_RAM_MB:=4096}" "${QEMU_BIN:=qemu-system-x86_64}" "${QEMU_ACCEL:=auto}"
: "${NETWORK_MODE:=bridge}" "${BRIDGE_NAME:=br-gleiphnir}" "${VM_IP:=192.168.100.10}"
# ... HOST_SSH_FORWARD_PORT=2233, VM_HOSTNAME, etc. config/sandbox.env:17-66
[[ -z "${UBUNTU_IMAGE_URL:-}" ]] && UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-${UBUNTU_ARCH}.img"
# derived: BASE_IMAGE/PID_FILE/CONSOLE_LOG/MAC_FILE/MONITOR_SOCK vm/scripts/lib.ps1:112-116
# expand ~/ → $HOME vm/scripts/lib.ps1:89-98
# otel helpers: start_span/end_span checking otel-cli + OTEL_EXPORTER_OTLP_ENDPOINT vm/scripts/lib.ps1:246-275
```

Helpers to port: `get_vm_mac` `vm/scripts/lib.ps1:138-145` (`vm/images/mac.addr`), `get_qemu_pids` `/proc` scan only `vm/scripts/lib.ps1:168-173` (after `001` no `Win32_Process`), `require_base_image` `vm/scripts/lib.ps1:183`, `ssh_common_args` `StrictHostKeyChecking=no` `vm/scripts/lib.ps1:194-197`, `invoke_admin_ssh`/`with_fallback` `vm/scripts/lib.ps1:201-240` → `ssh -i $ADMIN_SSH_PRIV_PATH -p $HOST_SSH_FORWARD_PORT` fallback to `$VM_IP`.

**Per-script mapping (representative):**

- `start-vm.sh`: `set -euo pipefail; source lib.sh; trap 'end_span ERROR' ERR; ... qemu-img check`, bridge exists `ip link show $BRIDGE_NAME` `vm/scripts/start-vm.ps1:37`, accel `if [[ $QEMU_ACCEL == auto ]]; then [[ -e /dev/kvm ]] && ACCEL=(-enable-kvm -cpu host) || ACCEL=(-cpu qemu64)` `vm/scripts/start-vm.ps1:78`, `netdev=tap,id=net0,...
- `prepare-vm.sh`: `qemu-img create -f qcow2 -F qcow2 -b $BASE_IMAGE` `vm/scripts/prepare-vm.ps1:37`, admin key `gen-key.sh`, `python3 template_userdata.py $tmp $REPO_ROOT ...`, `network-config.bridge.yaml` sed `__VM_IP__` `vm/scripts/prepare-vm.ps1:80-84`, ISO build `for tool in cloud-localds genisoimage mkisofs; do ...; done; python3 build_seed_iso.py` `vm/scripts/prepare-vm.ps1:109-152` (no `oscdimg` post-001).
- `network-up.sh`: `if [[ $EUID -ne 0 ]]; then echo "run as root: mise run network:up"` `vm/scripts/network-up.ps1:19`; `ip link add br-gleiphnir type bridge`, `ip tuntap add dev tap-gleiphnir mode tap user $SUDO_USER`, `ip link set tap master br-gleiphnir`, `iptables -t nat ... DNAT` `vm/scripts/network-up.ps1:109-116`.
- `stop-vm.sh`: `printf quit | socat - UNIX-CONNECT:$MONITOR_SOCK` `vm/scripts/stop-vm.ps1:7-30` → fallback `kill $(cat $PID_FILE)`.
- `manage-policy.sh`: `shell_escape() { printf %q "$1"; }` replaces `Escape-ShellArg` `vm/scripts/manage-policy.ps1:35`, `invoke_admin_ssh "sudo /usr/local/bin/sandbox-policy $cmd"`.

**Callers:**

- `mise.toml:9` delete `[tools] powershell`, every `run = "pwsh -NoProfile -File ..."` → `run = "bash '{{ config_root }}/vm/scripts/*.sh'"`. `network:up/down` `mise.toml:52,57` `sudo -E {{ which('bash') }}` (no `which('pwsh')`). Keep `mise.toml:11` `otel-cli`, `syft`, `opencode`.
- `vm/scripts/prepare-vm.sh` still invokes `python3 template_userdata.py` / `build_seed_iso.py` exactly as before.

**Docs:** `README.md:112` `pwsh 7+` → `bash 5+`, `docs/linux-local.md:6` `apt: qemu-system-x86 qemu-utils iproute2 iptables python3-pycdlib bash`, `docs/architecture.md:9` `vm/scripts/*.sh bash+lib.sh`, `.devcontainer/Dockerfile` if installs `powershell`.

## Files to touch

- New: `vm/scripts/lib.sh` (+ maybe `vm/scripts/common.sh` alias)
- Rename: 28× `vm/scripts/*.ps1` → `*.sh` (keep `.ps1` redirect shim for one release if desired, then delete)
- Edit: `mise.toml`, `config/sandbox.env` comments (`QEMU_ACCEL=auto` comment `config/sandbox.env:25`), `README.md`, `docs/linux-local.md`, `docs/architecture.md:9`, `.gitignore` if logs, CI `*.ps1` refs

## Verification

```bash
shellcheck vm/scripts/*.sh   # 0 warnings, disable SC1091 for lib.sh source
bash -n vm/scripts/*.sh
rg -n "pwsh|\.ps1|PSScriptRoot" vm/scripts/ mise.toml  # host side 0 (guest vm/guest/bin/* bash ok)
mise run deps
mise run up
mise run smoke
mise run vm:info
ssh admin@192.168.100.10 "sudo sandbox-policy ls --wide | head -20"
ssh admin@192.168.100.10 "sandbox-shell --help | head -5"  # guest still pwsh landing
```

## Rollback

Branch `chore/tasks-002-pwsh-to-bash`. Keep `*.ps1` in git history; `mise.toml` can re-add `pwsh` shim. Guest unaffected.

## Checklist

- [ ] `vm/scripts/lib.sh` strict+otel helpers, sources `config/sandbox.env` with defaults
- [ ] 28 scripts ported, `shellcheck` pass, `bash -n` pass
- [ ] `mise.toml` all `pwsh`→`bash`, `powershell` tool removed, `otel-cli` kept
- [ ] `README.md` prereqs `bash` not `pwsh`
- [ ] `mise run deps/up/smoke` pass on KVM
- [ ] Status `done`
