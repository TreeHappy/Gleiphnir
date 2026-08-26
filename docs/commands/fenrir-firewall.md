# `fenrir firewall` — VM firewall (deprecated → policy)

**Spec:** `container/files/carapace/specs/fenrir.yaml:244` `firewall` (`sandbox-firewall`)
**Binary:** `container/files/fenrir:275` `sandbox-firewall`

## Synopsis

```
fenrir firewall allow <ip>            # Allow IP/CIDR → tcp/22 (compat)
fenrir firewall deny <ip>             # Deny IP
fenrir firewall remove <ip>           # aliases: delete, unallow, undeny
fenrir firewall enforce               # alias: lockdown — drop bootstrap any→:22
fenrir firewall list                  # aliases: show, status — ufw status numbered
fenrir firewall ingress allow <ip> [--port PORT] [--proto tcp|udp]
fenrir firewall egress allow <dst> [--port PORT] [--proto tcp|udp]
```

## Description

Wraps `ufw` with ingress/egress. Persisted via `ufw.service`. Deprecated in favor of `fenrir policy` (domain + IP).

| Subcommand | Alias | Description |
|---|---|---|
| `fenrir firewall allow <ip>` | — | Allow IP/CIDR → `tcp/22` (compat) |
| `fenrir firewall deny <ip>` | — | Deny IP |
| `fenrir firewall remove <ip>` | `delete, unallow, undeny` | Remove rules |
| `fenrir firewall enforce` | `lockdown` | Drop bootstrap `any→:22` |
| `fenrir firewall list` | `show, status` | `ufw status numbered` |
| `fenrir firewall ingress allow <ip>` | — | Ingress port-aware (ufw) |
| `fenrir firewall egress allow <dst>` | — | Egress port-aware (ufw) |

## Examples

```bash
fenrir firewall allow 203.0.113.42
fenrir firewall list
fenrir firewall enforce
```

## See Also

- New: `docs/commands/fenrir-policy.md`, `docs/policy.md`
- Impl: `vm/guest/bin/sandbox-firewall:1`
- Host compat: `docs/commands/gleiphnir-firewall.md`
