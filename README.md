# Gleiphnir

Open-source alternative to [Docker Sandbox](https://www.docker.com/products/docker-sandbox) built only with open-source components: **QEMU + Ubuntu 26.04 + ufw + Podman + mise + pwsh**.

Each developer SSHes into an Ubuntu VM and lands directly in an **ephemeral, read-only Podman container** whose default shell is **pwsh** (bash still available). The container has no `sudo`, `--cap-drop ALL`, a read-only rootfs, and mounts three volumes: the persistent workspace, a per-user persistent home, and a **shared mise volume** so toolchains download once for everyone.

Host-side orchestration is pure **PowerShell (`pwsh`)** driven by **mise tasks** — identical commands work on Linux and Windows.

## Architecture

```
Host (Linux+KVM or Windows+WHPX/TCG)
 └─ QEMU VM  — Ubuntu 26.04 ("resolute") cloud image
     ├─ bridge mode (Linux): TAP → br-gleiphnir, DNAT :2222 → VM:22
     │    (real client IPs preserved → guest ufw can filter them)
     │  user mode (Windows default): QEMU NAT hostfwd :2222 → VM:22
     │    (zero host changes; Gleiphnir never touches host firewall)
     ├─ Guest firewall: ufw — default-deny incoming, tcp/22 allow-list
     ├─ Data disk /dev/vdb → /srv/sandbox (ext4)   ← per-user workspaces (/work)
     ├─ Podman containers:
     │   • ubuntu:26.04 · read-only rootfs · --cap-drop ALL · no-new-privileges
     │   • user dev (uid 1000), sudo removed, login shell = pwsh launcher
     │   • /work            ← workspace bind mount (persistent)
     │   • /home/dev        ← named volume gleiphnir-home-<user> (~ persists)
     │   • /opt/mise-shared ← shared volume sandbox-mise (tools download once)
     │   • tools via mise: node/python/go/dotnet/nvim(+AstroNvim)/yazi/fzf/fd/
     │     rg/delta/hunk/leaf/carapace/atuin/opencode/pwsh ...
     └─ Users:
         • admin (your key, full sudo) — manages users + firewall
         • sandbox users — login shell = sandbox-shell → container(pwsh)
```

## Prerequisites

- **pwsh 7+** ([PowerShell](https://learn.microsoft.com/powershell/) — `snap install powershell --classic` / `winget install Microsoft.PowerShell`)
- **mise** (`curl https://mise.run | sh`) — task runner; `mise install` at repo root
- Linux hosts: `qemu-system-x86_64`, `qemu-img`, plus *one* of cloud-localds / genisoimage / `pip install pycdlib`; bridge mode additionally needs `ip`, `iptables`
- Windows hosts: [QEMU for Windows](https://qemu.weilnetz.de/) on PATH, OpenSSH client, git, python3 (+ `pip install pycdlib`). Enable *Virtual Machine Platform* for WHPX acceleration, or set `QEMU_ACCEL=tcg`.

```bash
mise run deps   # verifies your platform's toolchain
```

## Quickstart

```powershell
# 1. See tasks / check deps
mise run            # lists all tasks
mise run deps

# 2. Full bring-up (downloads image, prepares disks+seed ISO, starts VM, waits for SSH)
mise run up

# 3. Watch boot if needed
mise run vm:console   # or: mise run vm:info

# 4. SSH as admin
mise run vm:ssh

# 5. Create a sandbox user (host side, proxies to VM over SSH)
mise run user:add USER=alice KEY=~/.ssh/id_ed25519.pub

# 6. Log in as sandbox user — you land straight in the container (pwsh):
ssh alice@192.168.100.10           # or: ssh -p 2222 alice@<host-ip>

# Inside the container:
$PSVersionTable.PSEdition          # Core
nvim .                             # AstroNvim, EDITOR=nvim pre-wired
git diff                           # paged through delta
hunk diff                          # review-first diff viewer
leaf README.md                     # markdown reader
mise use node@22                   # extra tools install into shared cache

# 7. Firewall (ufw inside the VM)
mise run fw:allow IP=203.0.113.42  # let your IP reach SSH
mise run fw:list
mise run fw:enforce                # drop bootstrap rule → strict allow-list only

# 8. Tear down
mise run down                      # vm:stop + network:down
```

## Configuration

All tunables live in `config/sandbox.env` (loaded by mise `[env]` + `lib.ps1`). Highlights:

| Variable | Default | Notes |
|---|---|---|
| `NETWORK_MODE` | `bridge` | `bridge` = private bridge + DNAT (**Linux only**) · `user` = QEMU NAT, zero host changes (forced on Windows) |
| `PHYS_IF` | *(empty)* | Enslave a real NIC for a true LAN bridge (wired only) |
| `HOST_SSH_FORWARD_PORT` | `2222` | Host forward to VM sshd |
| `UBUNTU_RELEASE` | `resolute` | Ubuntu 26.04 LTS |
| `QEMU_ACCEL` | `auto` | `kvm` (Linux) / `whpx` (Windows) / `tcg` |
| `QEMU_MONITOR_PORT` | `4444` | Monitor TCP port on Windows hosts (unix socket on Linux) |
| `VM_CPUS` / `VM_RAM_MB` | `4` / `4096` | |

## Firewall (ufw)

The guest owns all firewalling — the host stays untouched. Provision opens tcp/22 to *any* via a bootstrap rule (never locks you out); then:

```powershell
mise run fw:allow IP=<your-ip>    # allow-list entries
mise run fw:enforce               # remove bootstrap → strict allow-list only
mise run fw:deny  IP=192.0.2.77   # block an IP everywhere
mise run fw:remove IP=...         # undo
```

In `user` (NAT) mode every client appears as 10.0.2.x inside the VM, so per-IP rules are meaningful only in bridge mode (Linux).

## Container & mise

- **Base**: `ubuntu:26.04` + git/curl/etc.; `sudo` removed.
- **Default shell**: pwsh via `/usr/local/bin/sandbox-pwsh` (a bash launcher that resolves the mise-installed pwsh from the shared volume; falls back to bash until first install).
- **Shared tools volume** (`sandbox-mise` → `/opt/mise-shared`): warmed automatically after image build — common toolchains download **once** for all users. Extra `mise use ...` installs land there too and are instantly available to everyone.
- **Per-user home volume** (`gleiphnir-home-<user>`): `~/.cache`, `~/.local` (atuin history!), `~/.config` persist across restarts.
- **Dotfiles via mise**: bashrc / pwsh profile / gitconfig ship at `/etc/sandbox/dotfiles` and are linked by the `dotfiles` mise task on each start. Personal overrides: put same-named files in `/work/dotfiles/`.
- **Editor/diff stack**: nvim + AstroNvim (seeded per workspace), delta as git pager, hunk aliases (`git hdiff`/`git hshow`), leaf markdown reader, yazi file manager, fzf/fd/rg, carapace completions, atuin history, opencode agent, dotnet/node/python/go.

## Sandbox users & workspaces

- Login shell is `sandbox-shell`: spawns the podman container with the three-volume layout above (`--userns keep-id`, rootful fallback).
- Workspace `/srv/sandbox/<user>` on the dedicated data disk; seeded README on first login.
- Admin management:
  ```powershell
  mise run user:add USER=carol KEY=/tmp/carol.pub
  mise run user:list
  mise run user:remove USER=carol   # also removes her home volume
  ```

## Task reference (mise)

```
mise run deps             # host dependency check (per-platform hints)
mise run gen:key          # admin SSH keypair
mise run image:download / image:info
mise run network:up / down / status      # Linux bridge (sudo); Windows no-op
mise run vm:prepare / start / stop / kill
mise run vm:console / vm:ssh / vm:ssh:wait / vm:info
mise run vm:clean [-All]                 # via vm:clean / vm:clean:all
mise run user:add|remove|list            # KEY=/IP= style args accepted
mise run fw:allow|deny|remove|list|enforce
mise run container:build / container:info
mise run smoke                           # end-to-end checks vs running VM
mise run up / down                       # convenience bundles
```

## Security model

- **Host isolation**: QEMU VM, separate kernel. On Windows, Gleiphnir performs **no** host networking or firewall changes.
- **Network isolation**: guest ufw default-deny incoming; only allow-listed IPs reach `sshd` after `fw:enforce`. Forward/output stay open (containers need egress/DNS).
- **Container isolation**: read-only rootfs, tmpfs `/tmp`+`/run`, no-new-privileges, caps dropped, resource limits, non-root `dev`, no sudo binary.

## Troubleshooting

- `KVM/WHPX not available` — enable virtualization (BIOS / Virtual Machine Platform) or set `QEMU_ACCEL=tcg` (slow).
- `Bridge conflicts` — leave `PHYS_IF=` empty; private bridge works on wifi. Bridging is Linux-only by design.
- `Cannot build seed ISO` — install cloud-image-utils/genisoimage, or simply `pip install pycdlib` (works everywhere).
- `Locked out of SSH after enforce?` — console in via `mise run vm:console`, then `sudo sandbox-firewall allow <ip>`.
- `pwsh missing inside fresh container` — first boot offline: launcher fell back to bash; once network allows, restart the shell and mise installs pwsh.
- `VM SSH unreachable` — `mise run vm:console` / `vm:info`; check `vm/images/console.log`.

## Repo layout

```
mise.toml                           task runner + env loading (replaces Taskfile)
config/sandbox.env                  tunables consumed by mise + lib.ps1
vm/
  scripts/                          ALL host scripting (PowerShell 7+)
    lib.ps1                         shared config/helpers (ports of old lib.sh)
    deps.ps1 gen-key.ps1 download-image.ps1 image-info.ps1 clean-vm.ps1
    prepare-vm.ps1 template_userdata.py build_seed_iso.py
    network-up/down/status.ps1      bridge+TAP+DNAT (Linux) / friendly no-op (Windows)
    start-vm.ps1 stop-vm.ps1 kill-vm.ps1 wait-ssh.ps1 …
    manage-user.ps1 manage-firewall.ps1 container-*.ps1 smoke-test.ps1
  cloud-init/user-data.yaml.tpl     ufw posture + guest/container provisioning
  guest/bin/sandbox-shell           login shell → podman (3-volume layout)
  guest/bin/sandbox-user            user lifecycle (incl. home-volume cleanup)
  guest/bin/sandbox-firewall        ufw allow/deny/remove/enforce/list
  guest/lib/build-container.sh      podman build + shared-mise warm-up
container/
  Containerfile                     ubuntu:26.04, pwsh launcher as login shell
  entrypoint.sh                     mise bootstrap → dotfiles → exec pwsh
  files/mise.toml                   manifest (tools + env defaults + dotfiles task)
  files/dotfiles/                   bashrc, profile.ps1, gitconfig
  files/start-pwsh.sh               stable pwsh launcher (bash → exec pwsh)
docs/architecture.md                contributor deep-dive
```

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Copyright 2026 TreeHappy.
