# `fenrir proxy` — DENIED yolo inside (host `gle obs` only)

> **Yolo: `fen proxy` denied inside** `container/files/fenrir:272 deny_inside` — `mitmproxy 8080` `vm/guest/bin/sandbox-proxy:21` `upstream_cert=false:280` + `haproxy E req.ssl_sni -m end` `tasks/003:30` are host VM only `user-data.yaml.tpl:29 packages: mitmproxy` + `vm/guest/lib/otelcol-config.yaml:120`. Container already gets `http_proxy=http://$VM_IP:8080` `vm/guest/bin/sandbox-shell:138`.

**Spec (yolo):** removed from `container/files/carapace/specs/fenrir.yaml:222`; host `gle obs` manages.
**Binary:** `container/files/fenrir:272 deny_inside`, host `vm/guest/bin/sandbox-proxy:1`.

## Synopsis (denied yolo)

```
# inside fen proxy → denied
fen proxy --listen-port 8080  # -> error: denied inside, use gle

# host VM only
sudo sandbox-proxy --listen-port 8080 --log-dir /var/log/sandbox  # VM via gle obs
```

## Description

Starts the `mitmproxy` MITM proxy addon that exports OTel spans + JSONL and enforces the policy allowlist. `request()` checks host vs `global.deny` then allowlist (`**` = allow all), 403s on `egress_denied` with `proxy-*.jsonl` log (tailed by OTel Collector). Env `http_proxy=http://$VM_IP:8080` is injected by `sandbox-shell` (`vm/guest/bin/sandbox-shell:138`).

| Flag | Description |
|---|---|
| `--listen-port <port>` | Proxy listen port (default: 8080) |
| `--log-dir <dir>` | JSONL log directory |
| `--otel-endpoint <url>` | OTel Collector OTLP/HTTP endpoint |

## Examples

```bash
fenrir proxy --listen-port 8080 --log-dir /var/log/sandbox
fenrir proxy --otel-endpoint http://127.0.0.1:4317
```

## See Also

- Impl: `vm/guest/bin/sandbox-proxy:21`
- Policy: `docs/policy.md`, `docs/commands/fenrir-policy.md`
- `vm/guest/bin/sandbox-shell:126` (env injection)
