# Windows Server Mode

Run Gleiphnir on a Windows machine and access it remotely via SSH, Guacamole web terminal, and Grafana dashboards.

```
Remote Machine
  ├─ SSH Client ─────────────→ Windows Host
  │                               ├─ OpenSSH Server (:22)
  │                               ├─ QEMU VM (user-mode NAT)
  │                               │   └─ Podman sandbox (pwsh)
  │                               ├─ Grafana LGTM (:3000)
  │                               └─ Guacamole (:8080) ─→ SSH
  └─ Web Browser ──→ Guacamole ─→ SSH to host/VM
                 └─ Grafana (:3000)
```

> **Note:** Windows uses user-mode NAT — the VM is only reachable from the host itself (port 2222). All remote access goes through the Windows host.

## Prerequisites

### System

- Windows 10/11 or Windows Server with network access
- Same local prereqs as [windows-local.md](windows-local.md) (mise, pwsh, QEMU, python, pycdlib)

### Networking

- Static IP or known hostname for the Windows host
- Router/firewall must allow inbound traffic on required ports

### OpenSSH Server

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
```

### Podman (for Guacamole + LGTM containers)

```powershell
winget install RedHat.Podman   # or: winget install RedHat.Podman-Desktop
```

### SSH key setup (on remote client)

```powershell
ssh-keygen -t ed25519
scp ~/.ssh/id_ed25519.pub <user>@<host-ip>:~/.ssh/authorized_keys
```

## Deploy Gleiphnir

```powershell
cd Gleiphnir
mise install
mise run deps
mise run up
```

User-mode NAT: `hostfwd 0.0.0.0:2222 → VM:22`. Zero host changes.

## Enable Observability

Set in `config/sandbox.env`:

```
OBSERVABILITY_ENABLED=true
OBSERVABILITY_GRAFANA_PORT=3000
```

```powershell
mise run up    # or: mise run obs:start (if VM already running)
```

## Windows Firewall Rules

```powershell
New-NetFirewallRule -Name "SSH" -DisplayName "OpenSSH Server" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

New-NetFirewallRule -Name "Grafana" -DisplayName "Grafana Dashboard" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 3000

New-NetFirewallRule -Name "Prometheus" -DisplayName "Prometheus Metrics" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 9090

New-NetFirewallRule -Name "WebTerminal" -DisplayName "Guacamole" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 8080

New-NetFirewallRule -Name "QEMU-SSH" -DisplayName "QEMU VM SSH" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2222
```

Optional — restrict to a specific client IP by adding `-RemoteAddress <client-ip>` to each rule.

## Remote Access

### SSH to host (port 22)

```powershell
ssh <windows-user>@<host-ip>
cd Gleiphnir && mise run vm:ssh     # into the VM as admin
```

### Direct VM SSH (port 2222)

```powershell
ssh -p 2222 admin@<host-ip>          # VM admin
ssh -p 2222 <sandbox-user>@<host-ip> # pwsh sandbox
```

### Web Terminal — Apache Guacamole (port 8080)

```powershell
podman run -d --name guacamole `
  -p 8080:8080 `
  -e GUACD_HOSTNAME=host.docker.internal `
  oznu/guacamole
```

Or manual install:

1. Download `guacd` + Guacamole WAR from <https://guacamole.apache.org/releases/>
2. Configure SSH connection: host `127.0.0.1`, port `2222`
3. Start `guacd` + Tomcat

Access from browser: `http://<host-ip>:8080/guacamole`
Login: `guacadmin` / `guacadmin` — **change immediately**.

### Grafana Dashboard (port 3000)

`http://<host-ip>:3000`
Login: `admin` / `admin` — **change on first login**.

### Prometheus (port 9090)

`http://<host-ip>:9090`

## Port Reference

| Port | Service |
|------|---------|
| 22 | OpenSSH Server (Windows host) |
| 2222 | QEMU hostfwd → VM SSH |
| 3000 | Grafana |
| 4317 | OTLP gRPC (telemetry) |
| 4318 | OTLP HTTP (telemetry) |
| 4444 | QEMU monitor |
| 8080 | Guacamole web terminal |
| 9090 | Prometheus |

## Security

- Change default passwords (`admin`/`admin` on Grafana, `guacadmin`/`guacadmin` on Guacamole)
- Restrict firewall rules to known client IPs (`-RemoteAddress`)
- TLS via reverse proxy (nginx/Caddy) for Grafana + Guacamole
- SSH key-only auth (`PasswordAuthentication no` in `sshd_config`)
- VM-internal `ufw` still applies to sandbox users

## Troubleshooting

| Problem | Fix |
|---------|-----|
| SSH refused | `sc query sshd` / check firewall / check `sshd_config` |
| Grafana blank | `podman logs gleiphnir-lgtm` / check port 3000 firewall |
| Guacamole blank | `podman logs guacamole` / verify `guacd` is running |
| VM unreachable | `mise run vm:console` / check `vm/images/console.log` |
| WHPX not available | Enable virtualization in BIOS, or set `QEMU_ACCEL=tcg` |
