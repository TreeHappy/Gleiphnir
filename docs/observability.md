# Observability

Gleiphnir includes optional observability powered by the **Grafana LGTM stack** (Loki, Grafana, Tempo, Prometheus). When enabled, you get:

- **Session input logging** — every command typed by sandbox users is captured as structured JSONL
- **HTTP traffic capture** — outbound HTTP/HTTPS requests from sandbox containers are logged via a MITM proxy
- **System metrics** — CPU, RAM, disk, and network metrics from the VM via Prometheus node-exporter
- **User lifecycle auditing** — user add/remove events are logged
- **Grafana dashboards** — unified visualization of all signals at `localhost:3000`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ HOST MACHINE                                            │
│                                                         │
│  ┌──────────────────┐    ┌──────────────────────────┐   │
│  │ gleiphnir VM     │    │ gleiphnir-lgtm container │   │
│  │ (QEMU)           │    │ grafana/otel-lgtm        │   │
│  │                  │───>│                          │   │
│  │  node-exporter   │    │  Grafana   :3000         │   │
│  │  otel-collector  │    │  OTLP gRPC :4317         │   │
│  │  mitmproxy       │    │  OTLP HTTP :4318         │   │
│  │  session-logger  │    │  Prometheus:9090         │   │
│  └──────────────────┘    └──────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

The LGTM container runs as a **standalone Podman container on the host**, not inside the Gleiphnir VM. The VM ships telemetry to it over the network:

- **Bridge mode**: VM reaches LGTM at `192.168.100.1:4317` (host gateway)
- **User-mode NAT**: VM reaches LGTM at `10.0.2.2:4317` (QEMU gateway)

## Quick Start

### 1. Enable observability

Edit `config/sandbox.env`:

```bash
OBSERVABILITY_ENABLED=true
```

### 2. Bring up the stack

```bash
mise run up
```

This will:
1. Start the VM as usual
2. Start the LGTM container on the host
3. Deploy observability agents (OTel Collector, node-exporter, mitmproxy) into the VM

### 3. Open Grafana

```bash
mise run obs:open
```

Or open `http://localhost:3000` manually (login: `admin` / `admin`).

## Configuration

All settings are in `config/sandbox.env`:

| Setting | Default | Description |
|---------|---------|-------------|
| `OBSERVABILITY_ENABLED` | `false` | Master toggle for the entire observability stack |
| `OBSERVABILITY_LGTM_IMAGE` | `grafana/otel-lgtm:latest` | Docker image for the LGTM container |
| `OBSERVABILITY_GRAFANA_PORT` | `3000` | Grafana UI port on the host |
| `OBSERVABILITY_OTLP_PORT` | `4317` | OTLP gRPC receiver port on the host |
| `OBSERVABILITY_PROM_PORT` | `9090` | Prometheus metrics port on the host |
| `OBSERVABILITY_PROXY_ENABLED` | `true` | Enable HTTP traffic capture via MITM proxy |
| `OBSERVABILITY_SESSION_LOGGING` | `true` | Enable session input (keystroke) logging |

## Mise Tasks

| Task | Description |
|------|-------------|
| `mise run obs:start` | Start LGTM container + deploy agents to VM |
| `mise run obs:stop` | Stop LGTM container |
| `mise run obs:status` | Show LGTM status and access info |
| `mise run obs:open` | Open Grafana dashboard in browser |
| `mise run obs:deploy` | Re-deploy agents to running VM |
| `mise run obs:clean` | Remove LGTM container and data volume |

## What Gets Captured

### Session Input (Keystrokes)

When `OBSERVABILITY_SESSION_LOGGING=true`, the `sandbox-shell` login wrapper uses a PTY logger to capture user input. Each session produces a JSONL file at `/var/log/sandbox/session-<user>-<id>.jsonl`:

```json
{"timestamp":"2026-08-25T12:00:00Z","event":"session_start","user":"alice","session_id":"1724587200-1234"}
{"timestamp":"2026-08-25T12:00:05Z","event":"input_line","content":"ls -la"}
{"timestamp":"2026-08-25T12:00:10Z","event":"input_line","content":"git status"}
{"timestamp":"2026-08-25T12:05:00Z","event":"session_end","user":"alice","session_id":"1724587200-1234","exit_code":0}
```

### HTTP Traffic

When `OBSERVABILITY_PROXY_ENABLED=true`, sandbox containers route outbound HTTP/HTTPS traffic through a mitmproxy instance running inside the VM. All requests are logged as JSONL:

```json
{"timestamp":"2026-08-25T12:00:15Z","event":"http_request","method":"GET","url":"https://api.github.com/repos/...","host":"api.github.com","port":443,"scheme":"https","response_status":200,"response_size":1234,"duration_ms":150}
```

**Privacy note**: The MITM proxy decrypts HTTPS traffic for logging purposes. This data stays on your machine and is never sent externally. The proxy only runs inside the VM and only affects sandbox container traffic.

### System Metrics

Prometheus node-exporter runs inside the VM, scraping system metrics every 15 seconds:

- CPU usage (per-core)
- Memory usage
- Disk I/O and space
- Network traffic
- Filesystem metrics

The OTel Collector scrapes node-exporter and ships metrics to the LGTM container.

### User Lifecycle Events

The `sandbox-user` script logs add/remove events to `/var/log/sandbox/audit.jsonl`:

```json
{"timestamp":"2026-08-25T12:00:00Z","event":"user_add","user":"alice","admin":"admin","success":true}
{"timestamp":"2026-08-25T12:10:00Z","event":"user_remove","user":"alice","admin":"admin","success":true}
```

### Container Start Events

Each sandbox container emits a start event via `entrypoint.sh`:

```json
{"timestamp":"2026-08-25T12:00:00Z","event":"container_start","user":"dev","hostname":"sandbox","workspace":"/work"}
```

## Data Flow

1. **Guest scripts** (`sandbox-shell`, `sandbox-user`) write JSONL log files to `/var/log/sandbox/`
2. **mitmproxy** writes HTTP traffic logs to `/var/log/sandbox/proxy-*.jsonl`
3. **node-exporter** exposes metrics at `localhost:9100`
4. **OTel Collector** reads log files (filelog receiver) and scrapes node-exporter (prometheus receiver)
5. **OTel Collector** exports all signals via OTLP to the LGTM container on the host
6. **LGTM container** stores data in Loki (logs), Prometheus (metrics), and Tempo (traces)
7. **Grafana** provides dashboards and ad-hoc queries over all signals

## Resource Impact

| Component | Location | RAM | CPU | Disk |
|-----------|----------|-----|-----|------|
| LGTM container | Host | ~500 MB | Low idle | ~100 MB/day logs |
| node-exporter | VM | ~10 MB | Negligible | Negligible |
| OTel Collector | VM | ~50 MB | Low | Minimal |
| mitmproxy | VM | ~30 MB | Low | ~50 MB/day logs |
| **Total** | | **~590 MB** | **Minimal** | **~150 MB/day** |

The VM's 4GB RAM budget is barely affected (~90 MB). The host takes the brunt at ~500 MB for LGTM.

## Troubleshooting

### LGTM container won't start

```bash
# Check podman on host
podman ps -a | grep lgtm

# Check logs
podman logs gleiphnir-lgtm

# Force restart
mise run obs:stop
mise run obs:start
```

### No data in Grafana

1. Verify OTel Collector is running in the VM: `ssh admin@VM "systemctl status otelcol"`
2. Check OTel Collector logs: `ssh admin@VM "journalctl -u otelcol -f"`
3. Verify the LGTM endpoint is reachable from the VM: `ssh admin@VM "curl -s http://HOST_IP:4317"`
4. Check Grafana data sources: Open Grafana → Settings → Data Sources

### MITM proxy not capturing traffic

1. Check mitmproxy is running: `ssh admin@VM "systemctl status sandbox-proxy"`
2. Verify proxy port is open: `ssh admin@VM "ss -tlnp | grep 8080"`
3. Check that sandbox containers have proxy env vars: SSH into a sandbox, run `env | grep -i proxy`

### High disk usage

Loki and Prometheus data accumulates over time. To clean up:

```bash
# Stop LGTM, remove data volume, restart
mise run obs:clean
mise run obs:start
```

## Mise Layering

The observability stack integrates with Gleiphnir's mise-based architecture:

- **`config/sandbox.env`**: All observability settings live here alongside VM/network/container config
- **`mise.toml`**: `obs:*` tasks provide lifecycle management
- **`vm/scripts/`**: PowerShell scripts handle host-side LGTM and VM-side agent deployment
- **`vm/guest/bin/`**: Bash scripts handle guest-side observability hooks
- **`vm/cloud-init/`**: Packages (node-exporter, mitmproxy) are installed at VM boot
