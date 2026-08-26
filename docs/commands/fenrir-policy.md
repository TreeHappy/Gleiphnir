# `fenrir policy` — egress/ingress allowlists (sbx parity)

**Spec:** `container/files/carapace/specs/fenrir.yaml:311` `policy` (`sandbox-policy`)
**Binary:** `container/files/fenrir:278` `sandbox-policy`

## Synopsis

```
fenrir policy init [balanced|open|locked]
fenrir policy ls [--wide] [--json] [--sandbox NAME]
fenrir policy allow network <host|**|CIDR> [--port PORT] [--sandbox NAME]
fenrir policy deny network <host|CIDR> [--port PORT] [--sandbox NAME]
fenrir policy rm network --resource <host> [--sandbox NAME]
fenrir policy check network <host|url> [--sandbox NAME]
fenrir policy reset [--force]
fenrir policy preset list|apply <preset>|diff
```

## Description

Network policy like `sbx policy`. Domains/wildcards (`*.host`, `**`) via proxy allowlist (`/etc/sandbox/proxy-allowlist.txt`), CIDR/IP via `ufw`. Supports `--sandbox NAME` per-sandbox overrides. `balanced` preset covers npm/pypi/crates/go/nuget/maven/apt/mise/docker, github/ghcr, vscode, exa.ai/api.exa.ai.

| Subcommand | Description | Flags |
|---|---|---|
| `fenrir policy init [balanced|open|locked]` | Init preset (prompts if tty) | — |
| `fenrir policy ls` | List rules | `--wide`, `--json`, `--sandbox` |
| `fenrir policy allow network <host|**|CIDR>` | Allow host/wildcard/CIDR | `--port`, `--sandbox` |
| `fenrir policy deny network <host|CIDR>` | Deny host/CIDR (deny wins) | `--port`, `--sandbox` |
| `fenrir policy rm network --resource <host>` | Remove rule | `--resource`, `--id`, `--sandbox` |
| `fenrir policy check network <host|url>` | Test allowed | `--sandbox` |
| `fenrir policy reset` | Wipe + re-init balanced | `--force` |
| `fenrir policy preset list|apply|diff` | Presets | — |

Host equivalent is `gle policy` (`vm/files/carapace/specs/gleiphnir.yaml:106` → `mise run policy:*`).

## Examples

```bash
fenrir policy ls --wide
fenrir policy allow network registry.npmjs.org
fenrir policy allow network "*.exa.ai"
fenrir policy check network https://api.exa.ai/search
```

## See Also

- `docs/policy.md` (global) + `docs/policy/*.md` per subcommand
- Host: `docs/commands/gleiphnir-policy.md`
- Impl: `vm/guest/bin/sandbox-policy:1`, `vm/guest/bin/sandbox-proxy:21`
