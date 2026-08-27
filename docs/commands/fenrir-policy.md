# `fenrir policy` — egress/ingress allowlists (sbx parity) — yolo read-only

> **Yolo: inside container only `ls|check` allowed.** `init|allow|deny|rm|reset|preset` denied `container/files/fenrir:278 deny_inside` — use `gle policy` on host (`vm/files/carapace/specs/gleiphnir.yaml:136`). AI yolo must not mutate host firewall/`/etc/sandbox/proxy-allowlist.txt:11` or `ufw`.

**Spec (yolo):** `container/files/carapace/specs/fenrir.yaml:311` `policy ls|check` only (full spec on host `vm/files/carapace/specs/gleiphnir.yaml:136`)
**Binary:** `container/files/fenrir:278` `sandbox-policy` read path `sandbox-policy:243 ls` `401 check` (`domain_matches:130`)

## Synopsis

```
# yolo inside (allowed)
fenrir policy ls [--wide] [--json] [--sandbox NAME]
fenrir policy check network <host|url> [--sandbox NAME]

# denied yolo — use host (gle)
gle policy init [balanced|open|locked]          # fen policy init denied
gle policy allow network <host|**|CIDR> [--port PORT] [--sandbox NAME]
gle policy deny network <host|CIDR> [--port PORT] [--sandbox NAME]
gle policy rm network --resource <host> [--sandbox NAME]
gle policy reset [--force]
gle policy preset list|apply <preset>|diff
```

## Description

Network policy like `sbx policy` — yolo container **read-only**. Host `gle policy` owns all mutating ops. `fen` inside must not `allow/deny` via `sync_proxy_allowlist:165` or `ufw allow out:317`. Domains/wildcards (`*.host`, `**`) via proxy allowlist (`/etc/sandbox/proxy-allowlist.txt:11`), CIDR/IP via `ufw`. Supports `--sandbox NAME` per-sandbox overrides. `balanced` preset covers npm/pypi/crates/go/nuget/maven/apt/mise/docker, github/ghcr, vscode, exa.ai/api.exa.ai.

| Subcommand | Description | Flags | Yolo |
|---|---|---|---|
| `fenrir policy ls` | List rules (read-only) | `--wide`, `--json`, `--sandbox` | **allowed** |
| `fenrir policy check network <host|url>` | Test allowed (read-only) | `--sandbox` | **allowed** |
| `fenrir policy init [balanced|open|locked]` | Init preset | — | **denied yolo → `gle policy init`** |
| `fenrir policy allow network <host|**|CIDR>` | Allow host/wildcard/CIDR | `--port`, `--sandbox` | **denied yolo → `gle policy allow`** |
| `fenrir policy deny network <host|CIDR>` | Deny host/CIDR (deny wins) | `--port`, `--sandbox` | **denied yolo → `gle policy deny`** |
| `fenrir policy rm network --resource <host>` | Remove rule | `--resource`, `--id`, `--sandbox` | **denied yolo → `gle policy rm`** |
| `fenrir policy reset` | Wipe + re-init balanced | `--force` | **denied yolo → `gle policy reset`** |
| `fenrir policy preset list|apply|diff` | Presets | — | **denied yolo → `gle policy preset`** |

Host full is `gle policy` (`vm/files/carapace/specs/gleiphnir.yaml:106` → `mise run policy:*` → `ssh admin → sudo sandbox-policy`).

## Examples

```bash
# yolo inside (allowed)
fenrir policy ls --wide
fenrir policy check network https://api.exa.ai/search

# host (privileged)
gle policy allow network registry.npmjs.org
gle policy allow network "*.exa.ai"
```

## See Also

- `docs/policy.md` (global) + `docs/policy/*.md` per subcommand
- Host: `docs/commands/gleiphnir-policy.md`
- Impl: `vm/guest/bin/sandbox-policy:1`, `vm/guest/bin/sandbox-proxy:21`
