# Linux Server Mode

Run Gleiphnir on a Linux server and access it remotely via SSH, Guacamole web terminal, and Grafana dashboards.

```
Remote Machine
  ├─ SSH Client ─────────────→ Linux Server
  │                               ├─ OpenSSH Server (:22)
  │                               ├─ QEMU VM (bridge mode, real client IPs)
  │                               │   └─ Podman sandbox (pwsh)
  │                               ├─ Grafana LGTM (:3000)
  │                               └─ Guacamole (:8080) ─→ SSH
  └─ Web Browser ──→ Guacamole ─→ SSH to host/VM
                 └─ Grafana (:3000)
```

## Prerequisites

### System

- Linux server (Ubuntu/Debian/Fedora) with network access
- Same local prereqs as [linux-local.md](linux-local.md) (`qemu`, `cloud-utils`, `ip`, `iptables`, `mise`, `pwsh`)

### Static IP

Assign a static IP to the server so remote clients can reach it reliably.

### OpenSSH Server (usually pre-installed)

```bash
sudo systemctl enable --now sshd
```

### Podman (for Guacamole + LGTM)

```bash
sudo apt-get install podman   # or: dnf install podman
```

### SSH key setup (on remote client)

```bash
ssh-keygen -t ed25519
scp ~/.ssh/id_ed25519.pub <user>@<server-ip>:~/.ssh/authorized_keys
```

## Deploy Gleiphnir

```bash
cd Gleiphnir
mise run deps
mise run up
```

Bridge mode is default on Linux — real client IPs are preserved via DNAT.

### Bridge mode details

- Creates: `br-gleiphnir` (192.168.100.1) + `tap-gleiphnir`
- iptables DNAT: `0.0.0.0:2233` → `192.168.100.10:22`
- Real client IPs pass through → guest `ufw` can filter them

### Optional: true LAN bridge

Set `PHYS_IF=eth0` in `config/sandbox.env` to enslave a real NIC. The VM gets DHCP from your LAN and appears as a real device.

## Enable Observability

Set in `config/sandbox.env`:

```
OBSERVABILITY_ENABLED=true
OBSERVABILITY_GRAFANA_PORT=3000
```

```bash
mise run up    # or: mise run obs:start (if VM already running)
```

## Firewall Rules

### iptables (host-level)

The DNAT rule is created automatically by `network:up`. For Guacamole and Grafana, ensure `INPUT` allows the ports:

```bash
sudo iptables -I INPUT 1 -p tcp --dport 22   -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 2233 -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 3000 -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 9090 -j ACCEPT
```

Optional — restrict to a specific client IP:

```bash
sudo iptables -I INPUT 1 -p tcp --dport 3000 -s <client-ip> -j ACCEPT
```

Persist across reboots:

```bash
sudo netfilter-persistent save          # Debian/Ubuntu
# or: sudo iptables-save > /etc/iptables/rules.v4
```

### UFW alternative

```bash
sudo ufw allow 22/tcp
sudo ufw allow 2233/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 9090/tcp
sudo ufw reload
```

## Remote Access

### SSH to host (port 22)

```bash
ssh <user>@<server-ip>
cd Gleiphnir && mise run vm:ssh    # into the VM as admin
```

### Direct VM SSH (port 2233)

```bash
ssh -p 2233 admin@<server-ip>          # VM admin
ssh -p 2233 <sandbox-user>@<server-ip> # pwsh sandbox
```

In bridge mode, real client IPs are preserved — guest `ufw` can allow/deny them.

### Web Terminal — Apache Guacamole (port 8080)

```bash
podman run -d --name guacamole \
  -p 8080:8080 \
  -e GUACD_HOSTNAME=host.docker.internal \
  oznu/guacamole
```

Or manual install:

1. Download `guacd` + Guacamole WAR from <https://guacamole.apache.org/releases/>
2. Configure SSH connection: host `192.168.100.10`, port `22` (VM direct IP via bridge)
3. Start `guacd` + Tomcat

Access from browser: `http://<server-ip>:8080/guacamole`
Login: `guacadmin` / `guacadmin` — **change immediately**.

### Grafana Dashboard (port 3000)

`http://<server-ip>:3000`
Login: `admin` / `admin` — **change on first login**.

### Prometheus (port 9090)

`http://<server-ip>:9090`

## Port Reference

| Port | Service |
|------|---------|
| 22 | OpenSSH Server |
| 2233 | DNAT → VM SSH (preserves real client IPs) |
| 3000 | Grafana |
| 4317 | OTLP gRPC (telemetry) |
| 4318 | OTLP HTTP (telemetry) |
| 8080 | Guacamole web terminal |
| 9090 | Prometheus |

## Security

- Change default passwords (`admin`/`admin` on Grafana, `guacadmin`/`guacadmin` on Guacamole)
- Restrict `iptables`/`ufw` rules to known client IPs
- TLS via reverse proxy (nginx/Caddy) for Grafana + Guacamole
- SSH key-only auth (`PasswordAuthentication no` in `/etc/ssh/sshd_config`)
- Guest `ufw` applies to sandbox users — enforce allow-list for production
- Consider `PHYS_IF` for full LAN isolation if server is on a shared network

## Troubleshooting

| Problem | Fix |
|---------|-----|
| SSH refused | `sudo systemctl status sshd` / `sudo ufw status` |
| DNAT not working | `sudo iptables -t nat -L -n \| grep 2233` |
| Grafana blank | `podman logs gleiphnir-lgtm` / check port 3000 firewall |
| Guacamole blank | `podman logs guacamole` / verify `guacd` is running |
| VM unreachable | `mise run vm:console` / check `vm/images/console.log` |
| Bridge conflicts | Leave `PHYS_IF=` empty for private bridge (works on wifi) |
