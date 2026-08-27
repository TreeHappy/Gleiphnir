# `fenrir firewall` — DENIED yolo inside (deprecated → `gle policy`)

> **Yolo: `fen firewall` denied inside** `container/files/fenrir:275 deny_inside` — `ufw` `vm/guest/bin/sandbox-firewall:1` `require_root:56` `allow from IP to 22` `ufw default deny incoming` `user-data.yaml.tpl:261` are host-only. AI must not bypass `br-gleiphnir` `vm/scripts/network-up.ps1:26` or `HOST_SSH_FORWARD_PORT=2233`. Use `gle fw` / `gle policy` on host (`vm/files/carapace/specs/gleiphnir.yaml:104`).

**Spec (yolo):** removed from `container/files/carapace/specs/fenrir.yaml:244`; host keeps `vm/files/carapace/specs/gleiphnir.yaml:104`.
**Binary:** `container/files/fenrir:275 deny_inside`, host `vm/guest/bin/sandbox-firewall:1`.

## Synopsis (denied yolo, host only)

```
# inside fen firewall → denied
fen firewall allow 203.0.113.42  # -> error: denied inside, use gle

# host (privileged)
gle firewall allow <ip>            # or gle fw allow IP=...
gle firewall deny <ip>
gle firewall remove <ip>
gle firewall enforce
gle firewall list
gle firewall ingress allow <ip> [--port PORT]
gle firewall egress allow <dst> [--port PORT]
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
