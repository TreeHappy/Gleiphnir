# `fenrir proxy` — MITM HTTP proxy

**Spec:** `container/files/carapace/specs/fenrir.yaml:222` `proxy` (`sandbox-proxy`)
**Binary:** `container/files/fenrir:272` `sandbox-proxy`

## Synopsis

```
fenrir proxy [--listen-port <port>] [--log-dir <dir>] [--otel-endpoint <url>]
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
