# Gleiphnir architecture

See `README.md` for user-facing docs. This file is for contributors.

## Components

- **QEMU/KVM** (Linux) or **QEMU/WHPX-TCG** (Windows): runs an Ubuntu 26.04 cloud image with two virtio drives (system overlay + data disk) and a seed ISO for cloud-init. On Linux hosts, TAP (`tap-gleiphnir`) is enslaved to a private bridge (`br-gleiphnir` 192.168.100.0/24) and host DNAT (`iptables -t nat PREROUTING :2222 → VM:22`) preserves source IPs so **ufw inside the VM** can filter them. On Windows hosts, only QEMU user-mode NAT is used — Gleiphnir never modifies host networking or firewall.

- **Host scripting**: all `vm/scripts/*.ps1` (PowerShell 7+), sharing `lib.ps1`. Orchestration via **mise tasks** in the root `mise.toml` (the old Taskfile.yml was removed). `config/sandbox.env` is loaded through mise `[env] _.file` *and* parsed by `lib.ps1`.

- **cloud-init** (`vm/cloud-init/user-data.yaml.tpl` + `prepare-vm.ps1` + `template_userdata.py`):
  - Creates `admin` (sudo, provided SSH key), installs `podman`/`ufw`/`qemu-guest-agent` + `mitmproxy`, formats and mounts `/dev/vdb` at `/srv/sandbox`.
  - Drops guest scripts (`sandbox-shell`, `sandbox-user`, `sandbox-firewall` (ingress/egress), `sandbox-policy` (like `sbx policy`), `sandbox-proxy` (mitmproxy with allowlist), container build helper) plus Fenrir/Gleiphnir CLIs (`fenrir`/`fen`, `gleiphnir`/`gle`) via `write_files`, and container sources under `/opt/sandbox/container/` (including dotfiles, `fenrir`/`gleiphnir` binaries, `gdu`/`yazi` via mise, and the pwsh launcher) + policy presets `vm/guest/policy-presets/*.txt` → `/etc/sandbox/policy-presets/` (`balanced` covers npm/pypi/crates/go/nuget/maven, docker/gcr, github, vscode, exa.ai/api.exa.ai).
  - Applies ufw (default-deny incoming; tcp/22 open via a *bootstrap* rule so admin is never locked out) + `sandbox-policy init balanced` (default deny egress + curated allowlist via proxy `/etc/sandbox/proxy-allowlist.txt` + `ufw default deny outgoing`), enables `sandbox-container-build.service`, builds `localhost/sandbox:latest`, warms the shared mise volume, and locks `sshd` to key-only.

- **Guest scripts** (`vm/guest/`, stay bash — they run inside Ubuntu):
  - `sandbox-shell` — login shell; prepares `/srv/sandbox/$USER`, then `podman run --rm -it --read-only --cap-drop ALL --security-opt no-new-privileges` with three storage mounts:
    | mount | backing | scope |
    |---|---|---|
    | `/work` | bind `/srv/sandbox/<user>` (data disk) | per-user workspace |
    | `/home/dev` | named volume `gleiphnir-home-<user>` | per-user home (~/.cache, ~/.local, ~/.config persist) |
    | `/opt/mise-shared` | named volume `sandbox-mise` | **shared by all users** — mise toolchains download once |
    Rootless via `--userns keep-id` (`:rw,U` chowns volumes to the mapped user); rootful `sudo podman` fallback.
  - `sandbox-user` — `useradd -m -s /usr/local/bin/sandbox-shell`, subuid allocation, authorized_keys, workspace dir, `loginctl enable-linger`; on remove also deletes the user's home volume. Exposed via `fenrir user` (in-container) and `gleiphnir user` (host → `mise run user:*`).
  - `sandbox-firewall` — wraps **ufw** with ingress/egress: `allow|deny|remove|list|enforce` + `ingress allow|deny|remove --port/--proto` + `egress allow|deny|remove|enforce` (IP/CIDR). Persists via `ufw.service`. Exposed via `fenrir firewall` (deprecated → policy) and `gleiphnir fw` (compat). See `docs/policy.md`.
  - `sandbox-policy` — like `sbx policy`: `init|ls|allow|deny|rm|check|reset|preset` over `domain/wildcard/**` (via proxy allowlist `/etc/sandbox/proxy-allowlist.txt`) + CIDR/IP (via `ufw`). Supports `--sandbox NAME` per-sandbox overrides; `balanced` preset covers npm/pypi/crates/go/nuget/maven/apt/mise/docker, github/ghcr, vscode, exa.ai/api.exa.ai. Exposed via `fenrir policy` and `gleiphnir policy` → `mise run policy:*`. Docs: `docs/policy.md` + `docs/policy/*.md`.
  - `sandbox-proxy` — `mitmdump` addon that exports OTel spans + JSONL, now also enforces policy allowlist: `request()` checks `host` vs `global.deny` then allowlist (`**` = allow all), 403s on `egress_denied` with `proxy-*.jsonl` log (tailed by OTel Collector). Env `http_proxy=http://$VM_IP:8080` injected by `sandbox-shell`.
  - `sandbox-tools` — inspect and manage mise tool installs. Shows all tools (shared + personal) with versions and disk usage. Users can only delete from their personal installs (`~/.local/share/mise`); shared volume tools are protected. Subcommands: `list`, `info <tool>`, `clean <tool>`, `clean:all`, `volumes`, **`search` (proxy-aware npm/pypi/crates/github/exa.ai)**. In-container now via `fenrir tools …` which delegates `volumes` to **`gdu`** and browsing to **`yazi`/`yasi`**, `search` to `sandbox-tools search`.
  - `sandbox-sbom` — generate Software Bill of Materials for the container image, mise toolchains, and VM apt packages. Uses `syft` when available, falls back to manifest-based SBOM generation. Outputs SPDX 2.3 or CycloneDX 1.5 JSON. Subcommands: `container`, `tools`, `vm`, `all`. Exposed as `fenrir sbom` and `gleiphnir sbom`.
  - `build-container.sh` — podman build + **warm-up**: pre-installs the manifest (including `gdu` + `yazi`) into `sandbox-mise` so no user ever waits for downloads.

- **Container** (`container/`): `ubuntu:26.04` with `git`, mise binary, user `dev` (uid 1000, no sudo, login shell = `/usr/local/bin/sandbox-pwsh`). Entrypoint bootstraps mise against `/opt/mise-shared/*`, links dotfiles via the mise `dotfiles` task, then execs pwsh through `start-pwsh.sh` (bash fallback until first install). Default manifest at `/etc/sandbox/mise.toml`: node LTS, python 3.12, go, dotnet, ripgrep, fd, fzf, gh, delta, hunk, `yazi`/`yasi` + `gdu`, neovim (+AstroNvim seeded per workspace), leaf, carapace, atuin, opencode, pwsh. Binary `/usr/local/bin/fenrir` (`fen`) is baked in (`container/Containerfile:39`); `gleiphnir` is host-only via carapace shim `~/.config/carapace/bin/gleiphnir` (`vm/files/carapace/specs/gleiphnir.yaml` `run:`).

## SBOM (Software Bill of Materials)

`mise run sbom:*` / `gleiphnir sbom *` / `fenrir sbom *` tasks generate SPDX 2.3 or CycloneDX 1.5 JSON SBOMs for all project layers:

| Task | Scope | What it scans |
|---|---|---|
| `sbom:container` | Container image | `localhost/sandbox:latest` via syft, or Containerfile + mise.toml manifest |
| `sbom:tools` | Mise toolchains | `/opt/mise-shared/data/installs/` (shared volume) |
| `sbom:vm` | VM apt packages | `/var/lib/dpkg/status` (all installed .deb packages) |
| `sbom:all` | All of the above | Combined output |

SBOMs are generated via `fenrir sbom` (in-container) or `gleiphnir sbom` (host → `mise run`) which delegate to `sandbox-sbom` inside the VM, then copied to the host `sbom/` directory. The `syft` tool (host-side) is used when available; a fallback manifest-based generator handles offline or missing-syft scenarios.

## Dotfiles

Sandbox dotfiles ship from `/etc/sandbox/dotfiles/` inside the container image:

| File | Target | Purpose |
|---|---|---|
| `bashrc` | `~/.bashrc` | mise activation, atuin, carapace, audit journal, prompt |
| `profile.ps1` | `~/.config/powershell/profile.ps1` | Same for pwsh |
| `gitconfig` | `~/.gitconfig` | delta pager, hunk aliases, diff3 merge |
| `gitignore_global` | `~/.gitignore_global` | Global gitignore (OS, editor, language artifacts) |
| `inputrc` | `~/.inputrc` | readline config (case-insensitive completion, arrow-key history search) |
| `editorconfig` | `~/.editorconfig` | Editor defaults (UTF-8, LF, indent style per language) |

**Personalization**: run `mise run dotfiles:init` to scaffold `/work/dotfiles/` with editable copies. Files there override the defaults. The `dotfiles` task re-links on every container start.

## Shell completion (Carapace)

[Carapace](https://carapace.sh) provides multi-shell tab completion for all Gleiphnir commands, now **nested** under two CLIs. Host CLIs are in `vm/files/carapace/specs/` (host only), container CLIs in `container/files/carapace/specs/` (container). Deployed system-wide into the container at `/etc/carapace/specs/` (fenrir) and on host `~/.config/carapace/specs/` (gleiphnir via `vm/scripts/`).

> **Specs are executable** — `vm/files/carapace/specs/gleiphnir.yaml` has `run:` on every leaf (`carapace --run` → `mise run`); `container/files/carapace/specs/fenrir.yaml` remains completion-only (executes via `fenrir` bash shim → `gdu`/`yazi`/`sandbox-*`). Host `gleiphnir` shim `~/.config/carapace/bin/gleiphnir` → `vm/scripts/*.ps1` → `sandbox-*` → `ufw`/proxy. Legacy `vm/files/gleiphnir` shim remains for fallback. See `docs/policy.md` “Specs vs Execution”.

| Spec file | Command | Completions | Alias |
|---|---|---|---|
| `fenrir.yaml` (`container/files/...`) | `fenrir` | Nested `tools {list,info,clean,clean:all,volumes,browse,search}`, `user {add,remove,list}`, `secrets {list,set,remove,export,rotate}`, `sbom {container,tools,vm,all}`, `journal {--flags}`, `proxy {--flags}`, `firewall {allow,deny,remove,enforce,list,ingress{allow,deny,remove},egress{allow,deny,remove,enforce}}`, `policy {init,ls,allow,deny,rm,check,reset,preset}`, `browse`, `volumes` — volumes→`gdu`, browse→`yazi`, policy→`sandbox-policy` (like `sbx policy`), search→`exa.ai` | `fen` |
| `gleiphnir.yaml` (`vm/files/...` **host-only**) | `gleiphnir` | Nested `vm {prepare,start,stop,kill,console,ssh,ssh:wait,info,clean,clean:all}`, `user {add,remove,list}`, `fw {allow,deny,remove,list,enforce}` (deprecated → `policy`), `policy {init,ls,allow,deny,rm,check,reset,preset,dump}`, `container {build,info}`, `sbom {…}`, `tools {list,info,clean,clean:all,volumes,search}`, `obs {start,stop,status,open,deploy,clean}`, `secrets {init,encrypt,decrypt,sync,list,status}`, `image {download,info}`, `network {up,down,status}`, `up,down,smoke` — every leaf calls `mise run <task>` (`vm/scripts/manage-policy.ps1` for policy) | `gle` |
| `mise.yaml` | `mise` | Enhanced task completion with descriptions | — |

Legacy `sandbox-*.yaml` specs have been removed in favor of nested `fenrir`/`gleiphnir`. `fen` stays in container, `gle` stays on host (not mirrored to `container/files/` per user request — see `docs/policy.md` host spec note). Specs are loaded via `CARAPACE_SPEC_DIR=/etc/carapace/specs` (container `bashrc:23`) and host `~/.config/carapace/specs/` via manual `ln -s $PWD/vm/files/carapace/specs/gleiphnir.yaml`. See `docs/commands.md` for full reference.

## Volume tooling

`fenrir tools` (in-container, via `gdu`/`yazi`) and `gleiphnir tools` (host → `mise run tools:*`) provide visibility into mise tool installs (both delegate to `sandbox-tools`/`mise` with `gdu` now handling disk analysis):

| Command | Description | Delegation |
|---|---|---|
| `fenrir tools list` / `gleiphnir tools list` | List all tools (shared + personal) with versions and disk usage | `sandbox-tools list` / `mise run tools:list` |
| `fenrir tools info <tool>` | Detailed info: version, path, size, source (shared/personal) | `gdu` for size |
| `fenrir tools clean <tool>` | Remove a personal install (shared tools are protected) |  |
| `fenrir tools clean:all` | Remove all personal installs (with confirmation) |  |
| `fenrir tools volumes [--gdu]` | Show volume mounts, disk usage, and tool counts — **via `gdu`** | `gdu /opt/mise-shared`, `gdu $HOME`, `gdu /work` |
| `fenrir browse [path]` / `fenrir tools browse` | Browse volumes | **`yazi`/`yasi`** |
| `gleiphnir tools volumes` | Host-side volumes (proxies to VM) | `mise run tools:volumes` |

Host tasks: `gleiphnir tools list` → `mise run tools:list` etc. See `docs/commands.md#fenrir-tools`.

## Networking modes

- `bridge` (default, Linux hosts): private isolated bridge + DNAT. VM static `192.168.100.10/24` via cloud-init `network-config.bridge.yaml`. Works on wifi; if `PHYS_IF` is set the script enslaves it for a true LAN bridge.
- `user` (default on native Windows): QEMU `-netdev user,hostfwd=tcp::2222-:22`. Zero host changes. The VM sees `10.0.2.x` sources, so per-IP guest filtering is meaningless here — use bridge mode (Linux) when you need IP allow/deny semantics.

## Data flow

1. `gleiphnir up` (or `mise run up`) → `deps.ps1` → `download-image.ps1` → `prepare-vm.ps1` (overlay + data qcow2 + templated user-data → seed.iso via cloud-localds/genisoimage/pycdlib) → network-up (Linux bridge) → `start-vm.ps1` (`qemu-system-x86_64 … -daemonize` on POSIX; `Start-Process` detached on Windows; monitor = unix socket on Linux / TCP loopback on Windows).
2. VM boots, cloud-init applies ufw posture, mounts `/srv/sandbox`, builds the image (baking `fenrir`/`gleiphnir` + `gdu`/`yazi`), warms `sandbox-mise`.
3. `gleiphnir user add USER=alice` (or `mise run user:add USER=alice`) → `manage-user.ps1` SSHes as admin, runs `sandbox-user add` (also exposed as `fenrir user add` in-container).
4. `ssh alice@192.168.100.10` → shell = `sandbox-shell` → `podman run` → entrypoint → **pwsh** (AstroNvim/atuin/`fen`+`gle` carapace ready; `bash` still available). Inside: `fen tools volumes` → `gdu`, `fen browse` → `yazi`.

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
- gVisor/Kata Containers instead of Podman for stronger container isolation.
- SBOM diffing / drift detection (compare SBOMs across builds to catch supply chain changes).

## Observability (optional)

When `OBSERVABILITY_ENABLED=true` in `config/sandbox.env`, a **Grafana LGTM** stack provides dashboards for session input, HTTP traffic, system metrics, and user lifecycle events. The LGTM container runs on the **host** (not inside the VM) and receives OTLP telemetry from an OTel Collector running inside the VM.

Key components:
- **LGTM container** (`gleiphnir-lgtm`): Grafana + Loki + Tempo + Prometheus, managed by `vm/scripts/observability.ps1`
- **OTel Collector** (inside VM): reads log files + scrapes node-exporter, ships to LGTM via OTLP
- **node-exporter** (inside VM): system metrics (CPU, RAM, disk, network)
- **mitmproxy** (inside VM): MITM HTTP proxy for traffic capture with OTel span generation
- **session-logger** (inside VM): PTY wrapper for session input capture
- **audit logs** (inside VM): JSONL audit trail for user add/remove events
- **otel-cli** (host): all host-side pwsh scripts emit OTel spans via [otel-cli](https://github.com/equinix-labs/otel-cli), installed via mise. Spans are exported to the OTel Collector when observability is enabled.

Data flow: `guest scripts → JSONL files → OTel Collector → OTLP → LGTM container → Grafana UI`

Host pwsh scripts: `script start → otel-cli span start → work → otel-cli span end → LGTM container → Grafana Tempo`

See `docs/observability.md` for setup guide.
