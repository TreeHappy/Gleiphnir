# Gleiphnir architecture

See `README.md` for user-facing docs. This file is for contributors.

## Components

- **QEMU/KVM**: runs an Ubuntu cloud image with two virtio drives (system overlay + data disk) and a seed ISO for cloud-init. TAP (`tap-gleiphnir`) enslaved to a private bridge (`br-gleiphnir` 192.168.100.0/24). Host DNAT (`iptables -t nat PREROUTING :2222 → VM:22`) preserves source IPs so `nftables` inside the VM can filter them.

- **cloud-init** (`vm/cloud-init/user-data.yaml.tpl` + `prepare-vm.sh` templating):
  - Creates `admin` (sudo, provided SSH key), installs `podman`/`nftables`/`qemu-guest-agent`, formats and mounts `/dev/vdb` at `/srv/sandbox`.
  - Drops guest scripts (`sandbox-shell`, `sandbox-user`, `sandbox-firewall`, base nftables ruleset, container build helper) via `write_files`, and container sources under `/opt/sandbox/container/`.
  - Applies nftables (`/etc/nftables.conf`), enables `sandbox-container-build.service`, builds `localhost/sandbox:latest`, and locks `sshd` to key-only.

- **Guest scripts** (`vm/guest/`):
  - `sandbox-shell` — login shell; prepares `/srv/sandbox/$USER`, then `podman run --rm -it --read-only --tmpfs … --cap-drop ALL --security-opt no-new-privileges -v /srv/sandbox/$USER:/work:rw localhost/sandbox:latest`. Rootless via `--userns keep-id` with rootful `sudo podman` fallback.
  - `sandbox-user` — `useradd -m -s /usr/local/bin/sandbox-shell`, subuid allocation, authorized_keys, workspace dir, `loginctl enable-linger`.
  - `sandbox-firewall` — wraps `nft add/delete element inet filter {allow,deny}_{ipv4,ipv6}` and snapshots `nft list ruleset > /etc/nftables.conf`.

- **Container** (`container/`): `ubuntu:24.04` with `git`, `mise` binary, user `dev` (uid 1000, no sudo). `ENTRYPOINT` `entrypoint.sh` sets `MISE_DATA_DIR=/work/.mise/data` etc. (so `mise` writes to the RW workspace while rootfs stays read-only), creates `~/.bashrc` if missing, runs `mise trust --all && mise install --yes`, and execs `bash`. Default manifest at `/etc/sandbox/mise.toml` (node LTS, python 3.12, go, ripgrep, fd, fzf, gh).

## Networking modes

- `bridge` (default): private isolated bridge + DNAT. VM static `192.168.100.10/24` via cloud-init `network-config.bridge.yaml`. Works on wifi; no physical NIC enslavement. If `PHYS_IF` is set, the script enslaves it for a true LAN bridge (VM gets LAN DHCP).

- `user`: QEMU `-netdev user,hostfwd=tcp::2222-:22`. No sudo/bridge needed, but VM sees only `10.0.2.2` as source, so IP filtering must happen on the **host** (`iptables`/`nftables` there), not in the VM.

## Data flow

1. `task up` → `download-image.sh` → `prepare-vm.sh` (overlay + data qcow2 + templated user-data → seed.iso via `cloud-localds`) → `network-up.sh` (bridge+TAP+DNAT) → `start-vm.sh` (`qemu-system-x86_64 -enable-kvm … -drive system.qcow2 -drive data.qcow2 -drive seed.iso -netdev tap … -daemonize -serial file:console.log -monitor unix:…`).
2. VM boots, cloud-init runs `runcmd`, mounts `/srv/sandbox`, applies nftables, builds container, restarts sshd.
3. `task user:add USER=alice` → `manage-user.sh` SSHes as admin, runs `sandbox-user add`.
4. `ssh alice@192.168.100.10` → shell = `sandbox-shell` → `podman run` → inside `sandbox` container (`/work` RW, rest RO).

## Mise layering

- **apt**: `git`, `ca-certificates`, `curl`, `unzip` etc. (system-level, needed to bootstrap mise).
- **mise (binary)**: baked into the container image (`Containerfile`).
- **mise (toolchains)**: resolved at *runtime* from `/etc/sandbox/mise.toml` (or `/work/mise.toml` if the user provides one) into `/work/.mise/data`. `mise install --yes` is idempotent; offline or failed fetches don't block the shell.

## Testing

- `task smoke` — admin `podman run --rm --read-only … localhost/sandbox:latest bash -c "…"` checks: image exists, rootfs RO, /work writable, no sudo, git/mise present, firewall `allow → remove` cycle.

- Manual: `task vm:console`, `task vm:ssh`, `podman images`, `nft list ruleset`, SSH as sandbox user.

## Future work

- Packer golden image (optional, faster boot).
- CSI-like separate RW data drive per org (vs per-user subdirs).
- Auditing/logging (systemd journal → host, podman events).
- gVisor/Kata Containers instead of Podman for stronger container isolation.
- Optional: host-side `nftables` templating that mirrors VM allow-list when `NETWORK_MODE=user`.
