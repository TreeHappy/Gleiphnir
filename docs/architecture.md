# Gleiphnir architecture

See `README.md` for user-facing docs. This file is for contributors.

## Components

- **QEMU/KVM** (Linux) or **QEMU/WHPX-TCG** (Windows): runs an Ubuntu 26.04 cloud image with two virtio drives (system overlay + data disk) and a seed ISO for cloud-init. On Linux hosts, TAP (`tap-gleiphnir`) is enslaved to a private bridge (`br-gleiphnir` 192.168.100.0/24) and host DNAT (`iptables -t nat PREROUTING :2222 → VM:22`) preserves source IPs so **ufw inside the VM** can filter them. On Windows hosts, only QEMU user-mode NAT is used — Gleiphnir never modifies host networking or firewall.

- **Host scripting**: all `vm/scripts/*.ps1` (PowerShell 7+), sharing `lib.ps1`. Orchestration via **mise tasks** in the root `mise.toml` (the old Taskfile.yml was removed). `config/sandbox.env` is loaded through mise `[env] _.file` *and* parsed by `lib.ps1`.

- **cloud-init** (`vm/cloud-init/user-data.yaml.tpl` + `prepare-vm.ps1` + `template_userdata.py`):
  - Creates `admin` (sudo, provided SSH key), installs `podman`/`ufw`/`qemu-guest-agent`, formats and mounts `/dev/vdb` at `/srv/sandbox`.
  - Drops guest scripts (`sandbox-shell`, `sandbox-user`, `sandbox-firewall`, container build helper) via `write_files`, and container sources under `/opt/sandbox/container/` (including dotfiles and the pwsh launcher).
  - Applies ufw (default-deny incoming; tcp/22 open via a *bootstrap* rule so admin is never locked out), enables `sandbox-container-build.service`, builds `localhost/sandbox:latest`, warms the shared mise volume, and locks `sshd` to key-only.

- **Guest scripts** (`vm/guest/`, stay bash — they run inside Ubuntu):
  - `sandbox-shell` — login shell; prepares `/srv/sandbox/$USER`, then `podman run --rm -it --read-only --cap-drop ALL --security-opt no-new-privileges` with three storage mounts:
    | mount | backing | scope |
    |---|---|---|
    | `/work` | bind `/srv/sandbox/<user>` (data disk) | per-user workspace |
    | `/home/dev` | named volume `gleiphnir-home-<user>` | per-user home (~/.cache, ~/.local, ~/.config persist) |
    | `/opt/mise-shared` | named volume `sandbox-mise` | **shared by all users** — mise toolchains download once |
    Rootless via `--userns keep-id` (`:rw,U` chowns volumes to the mapped user); rootful `sudo podman` fallback.
  - `sandbox-user` — `useradd -m -s /usr/local/bin/sandbox-shell`, subuid allocation, authorized_keys, workspace dir, `loginctl enable-linger`; on remove also deletes the user's home volume.
  - `sandbox-firewall` — wraps **ufw**: `allow <ip> → tcp/22`, `deny <ip>` (all ports), `remove`, `list`, and `enforce` (deletes the bootstrap any→:22 rule once a real allow-list exists). Rules persist natively via `ufw.service`.
  - `build-container.sh` — podman build + **warm-up**: pre-installs the manifest into `sandbox-mise` so no user ever waits for downloads.

- **Container** (`container/`): `ubuntu:26.04` with `git`, mise binary, user `dev` (uid 1000, no sudo, login shell = `/usr/local/bin/sandbox-pwsh`). Entrypoint bootstraps mise against `/opt/mise-shared/*`, links dotfiles via the mise `dotfiles` task, then execs pwsh through `start-pwsh.sh` (bash fallback until first install). Default manifest at `/etc/sandbox/mise.toml`: node LTS, python 3.12, go, dotnet, ripgrep, fd, fzf, gh, delta, hunk, yazi, neovim (+AstroNvim seeded per workspace), leaf, carapace, atuin, opencode, pwsh.

## Networking modes

- `bridge` (default, Linux hosts): private isolated bridge + DNAT. VM static `192.168.100.10/24` via cloud-init `network-config.bridge.yaml`. Works on wifi; if `PHYS_IF` is set the script enslaves it for a true LAN bridge.
- `user` (default on native Windows): QEMU `-netdev user,hostfwd=tcp::2222-:22`. Zero host changes. The VM sees `10.0.2.x` sources, so per-IP guest filtering is meaningless here — use bridge mode (Linux) when you need IP allow/deny semantics.

## Data flow

1. `mise run up` → `deps.ps1` → `download-image.ps1` → `prepare-vm.ps1` (overlay + data qcow2 + templated user-data → seed.iso via cloud-localds/genisoimage/pycdlib) → network-up (Linux bridge) → `start-vm.ps1` (`qemu-system-x86_64 … -daemonize` on POSIX; `Start-Process` detached on Windows; monitor = unix socket on Linux / TCP loopback on Windows).
2. VM boots, cloud-init applies ufw posture, mounts `/srv/sandbox`, builds the image, warms `sandbox-mise`.
3. `mise run user:add USER=alice` → `manage-user.ps1` SSHes as admin, runs `sandbox-user add`.
4. `ssh alice@192.168.100.10` → shell = `sandbox-shell` → `podman run` → entrypoint → **pwsh** (AstroNvim/atuin/carapace ready; `bash` still available).

## Mise layering

- **apt (container)**: minimal OS layer to bootstrap mise.
- **mise (binary)**: baked into the container image and used on the host for task running.
- **mise (toolchains)**: container tools resolve from `/etc/sandbox/mise.toml` (or `/work/mise.toml`) into the **shared volume** `/opt/mise-shared/data` — one download serves every user/workspace. Warm-up makes this zero-cost after build; lazy installs still work (RW volume).
- **mise (config-as-code)**: `[env]` table provides EDITOR/VISUAL/PAGER/MANPAGER in both shells; the `dotfiles` task deploys bashrc/pwsh-profile/gitconfig (personal overrides in `/work/dotfiles` win).

## Testing

- `mise run smoke` — checks: SSH reachable, ufw active, podman works, image + shared volume exist, data disk mounted, container boots into **pwsh**, rootfs RO, /work writable, no sudo, git/mise present, mise env has EDITOR=nvim, core + extended toolset resolves, firewall allow→remove cycle.
- Manual: `mise run vm:console`, `mise run vm:ssh`, `podman images`, `sudo ufw status numbered`, SSH as a sandbox user, second login to confirm cache/history persistence.

## Future work

- Packer golden image (optional, faster boot).
- CSI-like separate RW data drive per org (vs per-user subdirs).
- ~~Auditing/logging (systemd journal → host, podman events).~~ **Done: see `docs/observability.md`.**
- gVisor/Kata Containers instead of Podman for stronger container isolation.

## Observability (optional)

When `OBSERVABILITY_ENABLED=true` in `config/sandbox.env`, a **Grafana LGTM** stack provides dashboards for session input, HTTP traffic, system metrics, and user lifecycle events. The LGTM container runs on the **host** (not inside the VM) and receives OTLP telemetry from an OTel Collector running inside the VM.

Key components:
- **LGTM container** (`gleiphnir-lgtm`): Grafana + Loki + Tempo + Prometheus + OTel Collector, managed by `vm/scripts/observability.ps1`
- **OTel Collector** (inside VM): reads log files + scrapes node-exporter, ships to LGTM via OTLP
- **node-exporter** (inside VM): system metrics (CPU, RAM, disk, network)
- **mitmproxy** (inside VM): MITM HTTP proxy for traffic capture
- **session-logger** (inside VM): PTY wrapper for session input capture
- **audit logs** (inside VM): JSONL audit trail for user add/remove events

Data flow: `guest scripts → JSONL files → OTel Collector → OTLP → LGTM container → Grafana UI`

See `docs/observability.md` for setup guide.
