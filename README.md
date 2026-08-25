# Gleiphnir

Open-source alternative to [Docker Sandbox](https://www.docker.com/products/docker-sandbox) built only with open-source components: **QEMU/KVM + Ubuntu + nftables + Podman + mise**.

Each developer SSHes into an Ubuntu VM and lands directly in an **ephemeral, read-only Podman container** (Ubuntu) with `mise` and standard tools. The container has no `sudo`, `--cap-drop ALL`, `--read-only` rootfs, and mounts only one RW volume: the persistent workspace on a dedicated data disk.

## Architecture

```
Host (Linux + KVM)
 └─ QEMU VM  — Ubuntu 24.04 cloud image
     ├─ TAP ── bridge br-gleiphnir (192.168.100.0/24)
     │         host DNAT :2222 → VM :22  (real client IPs preserved)
     │         └─ nftables: default-drop inbound, SSH only from allow-list
     ├─ Data disk /dev/vdb → /srv/sandbox (ext4)  ← workspaces
     ├─ Podman (rootless, — rootful fallback)
     │   └─ Container: ubuntu:24.04 + git + mise + tools
     │       • read-only rootfs,  --cap-drop ALL,  no-new-privileges
     │       • user `dev` (uid 1000), sudo removed
     │       • mise data dirs → /work/.mise/data (RW volume → toolchains persist)
     │       • ephemeral (--rm); workspace at /work persists
     └─ Users:
         • admin (your key, full sudo) — manages users + firewall
         • sandbox users — login shell = sandbox-shell → container
```

**Why TAP bridge instead of user-mode NAT?** With QEMU NAT every SSH connection appears as `10.0.2.2` inside the VM, so `nftables` cannot filter by real IP. A TAP bridge plus DNAT preserves the source address, so the VM sees the true client IP and can allow/deny it.

## Prerequisites

- Linux with KVM (`/dev/kvm`) — or WSL2 on Windows (KVM via Hyper-V nested). Native Windows without WSL2 works in slow TCG mode only.
- `qemu-system-x86_64`, `qemu-img`, `cloud-localds` (`cloud-image-utils`), `mise`, `task` (Taskfile runner), `iptables`/`nft` on the VM/host.

Install on Ubuntu/Debian:

```bash
sudo apt-get update && sudo apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils genisoimage iptables
# mise: https://mise.jdx.dev/getting-started.html
curl https://mise.run | sh
# task: https://taskfile.dev/installation/
sudo snap install task --classic   # or: go install github.com/go-task/task/v3/cmd/task@latest
```

Install tools via mise (see `mise.toml`):

```bash
mise install
```

## Quickstart

```bash
# 1. Check deps and see tasks
task deps
task --list

# 2. Full bring-up (downloads image, creates bridge/TAP, builds seed ISO, starts VM, waits for SSH)
task up

# 3. Watch boot if needed
task vm:console   # or: task vm:info

# 4. SSH as admin (manages the VM)
task vm:ssh
# inside VM:
sudo sandbox-user list
sudo sandbox-firewall list
podman images

# 5. Create a sandbox user (host side, proxies to VM)
task user:add USER=alice KEY=~/.ssh/id_ed25519.pub
# or: task user:add USER=bob   # uses your default ~/.ssh/id_*.pub

# 6. Log in as sandbox user — you land straight in the container:
ssh alice@192.168.100.10
# or via host forward from any machine that can reach the host:
ssh -p 2222 alice@<host-ip>

# Inside the container:
git --version
mise --version
mise use node@lts python@3.12   # installs into /work/.mise (persists)
touch /should-fail   # → Read-only file system
touch /work/hello && ls /work
exit   # container is removed; /work persists

# 7. Firewall: allow/deny IPs at the VM
task fw:allow IP=203.0.113.42
task fw:allow IP=198.51.100.0/24
task fw:deny  IP=192.0.2.99
task fw:list
task fw:remove IP=203.0.113.42

# 8. Tear down
task vm:stop
task network:down
task down   # both
```

## Configuration

All tunables are in `config/sandbox.env`. Override via environment or by editing the file. Key knobs:

| Variable | Default | Notes |
|---|---|---|
| `NETWORK_MODE` | `bridge` | `bridge` (isolated private bridge 192.168.100.0/24 + DNAT) or `user` (NAT, no bridge, IP filtering must happen on host) |
| `BRIDGE_NAME` / `TAP_NAME` | `br-gleiphnir` / `tap-gleiphnir` | |
| `BRIDGE_ADDR` / `VM_IP` | `192.168.100.1` / `192.168.100.10` | Private bridge subnet; change if it collides |
| `PHYS_IF` | *(empty)* | Set to `eth0`/`enp0s3` to enslave a real NIC and put the VM directly on your LAN (true LAN bridge; needs DHCP from LAN). Wifi (`wlan0`) won't bridge — leave empty. |
| `HOST_SSH_FORWARD_PORT` | `2222` | Host DNAT: `0.0.0.0:2222 → VM:22`. Real client IPs preserved. |
| `VM_CPUS` / `VM_RAM_MB` | `4` / `4096` | |
| `VM_DISK_SIZE` / `DATA_DISK_SIZE` | `20G` each | `DATA_DISK` is the persistent workspace volume |
| `UBUNTU_RELEASE` / `UBUNTU_ARCH` | `noble` / `amd64` | `arm64` works on ARM hosts |
| `ADMIN_USER` / `ADMIN_SSH_KEY_PATH` | `admin` / `~/.ssh/gleiphnir_admin` | Auto-generated if missing (`task gen:key`) |

## Firewall (nftables)

Inside the VM (`sudo sandbox-firewall …`) or from the host (`task fw:…`):

```bash
task fw:allow IP=203.0.113.5
task fw:allow IP=2001:db8::/32
task fw:deny  IP=192.0.2.77
task fw:remove IP=203.0.113.5
task fw:list
```

Rules are stored in `inet filter` sets `allow_ipv4`/`allow_ipv6` and `deny_ipv4`/`deny_ipv6`. The input chain is default-drop; `deny` is evaluated before `allow`. Changes are snapshotted to `/etc/nftables.conf` and survive reboots.

Host-side filtering: when `NETWORK_MODE=user` the VM cannot see real IPs; filter on the host with `iptables`/`nftables` instead.

## Container & mise

- **Base image**: `ubuntu:24.04` with `git`, `ca-certificates`, `curl`, etc. `sudo`/`su` are removed.
- **mise**: installed at `/usr/local/bin/mise`. A default manifest ships at `/etc/sandbox/mise.toml` (node LTS, python 3.12, go, ripgrep, fd, fzf, gh). Toolchains are installed **lazily** on first container start into `/work/.mise/data` (the RW workspace) and persist across sessions. Users extend it with their own `/work/mise.toml`.

```
# inside sandbox
mise use node@22 python@3.12 --global
mise install -y
node -v && python3 --version
rg --version
```

`MISE_DATA_DIR=/work/.mise/data`, `MISE_CACHE_DIR=/work/.mise/cache`, `XDG_*` all point at workspace subdirs so nothing writable is needed on the rootfs.

## Sandbox users & workspaces

- Users are Linux accounts on the VM whose shell is `/usr/local/bin/sandbox-shell`. They have **no password login** (SSH keys only) and their shell spawns `podman run --rm -it --read-only … -v /srv/sandbox/<user>:/work:rw localhost/sandbox:latest`. Replace `--userns keep-id` if rootless supports it; falls back to rootful via `sudo podman` when needed.
- Container limits: `--pids-limit 512 --memory 2g --cpus 2 --cap-drop ALL --security-opt no-new-privileges`.
- Workspace: `/srv/sandbox/<user>` on the dedicated ext4 data disk (`/dev/vdb`). Survives container restarts. Seed README created on first login.
- Admin management (host side):
  ```bash
  task user:add USER=carol KEY=/tmp/carol.pub
  task user:list
  task user:remove USER=carol
  ```

## VM lifecycle (Taskfile)

```
task deps             # host deps
task gen:key          # admin SSH key
task image:download   # Ubuntu cloud image
task image:info
task network:up       # bridge+TAP+iptables (sudo)
task network:down
task network:status
task vm:prepare       # overlay disk + data disk + seed ISO
task vm:start         # QEMU daemonized (-display none, monitor, console log)
task vm:ssh:wait      # poll until SSH up
task vm:ssh           # SSH as admin
task vm:console       # tail serial console
task vm:info
task vm:stop / vm:kill
task vm:clean [--all] # remove disks (and base image with --all)
task container:build  # (re)build localhost/sandbox:latest inside VM
task container:info
task smoke            # smoke test after VM is up
task up               # deps→download→prepare→start→wait
task down             # stop+network:down
```

## Security model

- **Host isolation**: VM via QEMU/KVM; separate kernel.
- **Network isolation**: `inet filter input` default-drop; only `tcp/22` from allow-list reaches `sshd`. `Forward`/`Output` stay permissive (containers need DNS/egress).
- **Container isolation**: read-only rootfs, tmpfs for `/tmp`/`/run`/`/home/dev`, no new privileges, all caps dropped, resource limits, `--rm` ephemeral, non-root `dev` (uid 1000), no `sudo` binary inside.

## Troubleshooting

- `KVM not available` — fall back to TCG (slow) or enable virtualization in BIOS / WSL2.
- `Bridge conflicts / wifi` — leave `PHYS_IF=` empty; the private bridge works on wifi. Only set `PHYS_IF` for wired LAN bridges.
- `nft: permission denied` — inside VM, use `sudo sandbox-firewall …`.
- `podman info: permission denied / rootless failed` — `sandbox-shell` falls back to `sudo podman`; ensure the sandbox user can `sudo podman` if rootless setup is missing subuid ranges (reported by `podman info`).
- `VM SSH unreachable` — `task vm:console` and `task vm:info`; check `vm/images/console.log` and `cloud-init status` via console.
- Seed ISO not building — install `cloud-image-utils` (`cloud-localds`).

## Windows portability

The `Taskfile.yml` runner and all `vm/scripts/*.sh` run under **WSL2** (they need bash, `ip`/`iptables`, and KVM). Install WSL2 + Ubuntu, then run the same `task` commands. Native Windows QEMU without WSL2 is not supported (no KVM, TAP unsupported).

## Repo layout

```
config/sandbox.env                 tunables consumed by Taskfile + scripts
Taskfile.yml                       portable orchestrator (replaces Makefile)
vm/
  cloud-init/
    user-data.yaml.tpl             cloud-init template (placeholders → prepare-vm.sh)
    network-config.*.yaml          bridge vs user NAT configs
  scripts/
    lib.sh, gen-key.sh, download-image.sh
    network-up/down/status.sh      bridge+TAP+DNAT
    prepare-vm.sh                  disks + seed ISO (inlines guest+container sources)
    start-vm.sh / stop-vm.sh / kill-vm.sh / wait-ssh.sh / ssh-admin.sh / console.sh / vm-info.sh / clean-vm.sh
    manage-user.sh / manage-firewall.sh / container-*.sh / smoke-test.sh
  guest/
    bin/sandbox-shell              login shell → podman run
    bin/sandbox-user               create/remove users, subuid, workspace
    bin/sandbox-firewall           nftables allow/deny/list
    nftables-sandbox.nft           base ruleset
    lib/build-container.sh         podman build helper (inside VM)
container/
  Containerfile                    ubuntu:24.04 + mise binary, no sudo, user dev
  entrypoint.sh                    MISE_*→/work/.mise, mise install --yes, exec bash
  files/mise.toml                  default tool manifest (node, python, go, rg, fd, fzf, gh)
  files/bashrc
```

## License

See `LICENSE`.
