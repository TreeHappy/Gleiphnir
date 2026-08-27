---
id: 001
title: Strip Windows support (Linux-only KVM/bridge)
status: done
priority: high
depends_on: []
estimate: "1d"
branch: chore/tasks-001-strip-windows
---

## Goal / Non-Goals

- **Goal:** Make Gleiphnir Linux-only, single `KVM`+`bridge`+`qemu -daemonize`+`unix:qemu-monitor.sock` path, deleting all Windows/`user`-NAT dual branches so `002` (bash) and `005` (single binary) have one code path. Lean host toward single binary + `qemu|firecracker`.
- **Non-Goals:** No Firecracker yet, no proxy/secrets redesign (see `003`/`004`), no bash rewrite yet (that is `002`).

## Current state (file:line refs)

- Dual OS detection `vm/scripts/lib.ps1:86` `$IsWin = [RuntimeInformation]::IsOSPlatform(Windows)`, `vm/scripts/lib.ps1:130` `Get-NullDevice` `NUL` vs `/dev/null`, `vm/scripts/lib.ps1:132` `Test-MonitorTcp` (`IsWin`→`tcp:4444` else `unix:`), `vm/scripts/lib.ps1:161-164` `Win32_Process` pid scan, `vm/scripts/lib.ps1:48-49` `QEMU_ACCEL auto|kvm|whpx|tcg` + `QEMU_MONITOR_PORT=4444` `config/sandbox.env:25-27`.
- `NETWORK_MODE=bridge|user` `config/sandbox.env:38-49` (`bridge`→TAP/DNAT `192.168.100.10` `QEMU_ACCEL=kvm`, `user`→`hostfwd tcp::2222-:22` Windows). Guards `vm/scripts/start-vm.ps1:23-26` `IsWin+bridge→user`, `vm/scripts/start-vm.ps1:30-35` `/dev/net/tun` fallback, `vm/scripts/network-up.ps1:7-14`/`network-down.ps1:7-14`/`network-status.ps1:7-15` `IsWin`/`user` early returns, `vm/scripts/prepare-vm.ps1:13-16` same, `vm/scripts/prepare-vm.ps1:73` `network-config.user.yaml` vs `bridge.yaml`, `vm/scripts/prepare-vm.ps1:130-136` `oscdimg` Windows fallback.
- QEMU launch: `vm/scripts/start-vm.ps1:71-77` `whpx` accel + `vm/scripts/start-vm.ps1:94-98` monitor `tcp:` vs `unix:`, `vm/scripts/start-vm.ps1:139-153` `if (-not IsWin) -daemonize else Start-Process` + `qemu-stderr.log`. `vm/scripts/lib.ps1:214-229` `Invoke-AdminSsh` `user`→`127.0.0.1:HOST_SSH_FORWARD_PORT` else `VM_IP`.
- Deps/docs: `vm/scripts/deps.ps1:22-36` `if (IsWin) Required on Windows: ... whpx ... winget` , `vm/scripts/install-deps.ps1:53-54` `Skipping apt — on Windows`, `vm/scripts/secrets.ps1:30` `winget install FiloSottile.age`, `vm/scripts/sbom.ps1:74` `IsWin ? NUL`, `mise.toml:52,57` `{% if os == 'windows' %}...{% else %}sudo...`, `README.md:13-16,111-116`, `docs/windows-local.md`, `docs/windows-server.md`, `docs/architecture.md:7,92-95` bridge vs user, `docs/linux-local.md` vs Windows.

## Proposed change

Delete, do not flag-guard:

- **Config:** `config/sandbox.env:25-27` keep `QEMU_ACCEL=auto` but resolve to `kvm|tcg` only (delete `whpx`), delete `QEMU_MONITOR_PORT`, set `NETWORK_MODE=bridge` hard default (keep var for phys bridge but no `user`), remove `Windows hosts default to whpx` comment.
- **lib:** `vm/scripts/lib.ps1` (or `lib.sh` after `002`) remove `IsWin`/`Get-NullDevice`/`Test-MonitorTcp`, hardcode `/dev/null`, `unix:$MONITOR_SOCK` `vm/scripts/lib.ps1:113-116`, pid scan `/proc` only `vm/scripts/lib.ps1:168-173`, `Invoke-AdminSsh` always `admin@$VM_IP` + fallback `127.0.0.1:$HOST_SSH_FORWARD_PORT` via DNAT still, but no `user` primary path. `BASE_IMAGE/PID_FILE/CONSOLE_LOG/MAC_FILE/MONITOR_SOCK` keep `vm/scripts/lib.ps1:112-116`.
- **VM lifecycle:** `vm/scripts/start-vm.ps1` keep `bridge`+`kvm/tcg` block `vm/scripts/start-vm.ps1:30-65,78-89`, delete `IsWin` branch `vm/scripts/start-vm.ps1:23-26,71-77,94-98`, keep single `& $QEMU_BIN @qemuArgs -daemonize` `vm/scripts/start-vm.ps1:141`, `monitorArg = "unix:$MONITOR_SOCK,server,nowait"` only. `prepare-vm.ps1` keep `bridge.yaml` only `vm/scripts/prepare-vm.ps1:73-84`, drop `oscdimg` `vm/scripts/prepare-vm.ps1:130-136` (leave `cloud-localds/genisoimage/pycdlib`+`build_seed_iso.py:19`), drop `IsWin` tun check. `network-up.ps1:7-14` etc. remove `IsWin` early returns, delete `user` branches, keep `ip link + bridge br-gleiphnir + TAP + iptables DNAT :2233→192.168.100.10:22` `vm/scripts/network-up.ps1:26-116`.
- **Tasks/docs:** `mise.toml:52,57` simplify to `sudo -E bash {{...}}` (after `002` bash), `README.md:13-16` keep Linux local/server table only, prereqs `qemu-system-x86 qemu-utils cloud-utils iproute2 iptables`, remove Windows. Delete `docs/windows-local.md`+`windows-server.md`, edit `docs/architecture.md`, `docs/policy.md:10`, `vm/scripts/deps.ps1:22-36` Linux-only list.

## Files to touch

- `config/sandbox.env` `constant` (defaults)
- `vm/scripts/lib.ps1` → `lib.sh` (see `002` sequential, coordinate)
- `vm/scripts/start-vm.ps1`, `prepare-vm.ps1`, `network-up.ps1`, `network-down.ps1`, `network-status.ps1`, `stop-vm.ps1`, `kill-vm.ps1`, `vm-info.ps1`, `deps.ps1`, `install-deps.ps1`, `secrets.ps1`, `sbom.ps1`, `ssh-admin.ps1`, `deploy-observability.ps1`
- `vm/cloud-init/network-config.user.yaml` (delete or keep as reference, not used)
- `mise.toml`, `README.md`, `docs/*.md`, `.github` CI if any

## Verification

```bash
rg -n "IsWin|whpx|oscdimg|IsWin|QEMU_MONITOR_PORT|NETWORK_MODE.*user" vm/scripts/ config/ mise.toml
# → 0 (except historical comments deleted)
mise run deps        # Linux checklist only: qemu-system-x86_64, qemu-img, cloud-localds|pycdlib, python3, ip, iptables
mise run up          # bridge+TAP+DNAT, downloads resolute image config/sandbox.env:10-15, qemu -daemonize, qemu.pid
mise run vm:info
mise run smoke
ssh admin@192.168.100.10 true  # real source IP preserved for vm/guest/bin/sandbox-firewall:1
ssh -p 2233 admin@127.0.0.1 true # DNAT fallback via HOST_SSH_FORWARD_PORT config/sandbox.env:50
```

## Rollback

Branch `chore/tasks-001-strip-windows`. `git revert`. No `user` fallback — users on Windows must stay on pre-001 tag.

## Checklist

- [x] Branch `chore/tasks-001-strip-windows`
- [x] `config/sandbox.env` defaults trimmed
- [x] `vm/scripts/*` `IsWin`/`whpx`/`oscdimg`/`user` removed, single `unix:` monitor + `-daemonize`
- [x] `mise.toml` sudo wrappers simplified
- [x] `docs/windows-*.md` deleted, `README.md`/`docs/architecture.md` updated
- [x] `rg IsWin` 0
- [x] `mise run deps/up/smoke` pass on KVM host
- [x] Status `done`
