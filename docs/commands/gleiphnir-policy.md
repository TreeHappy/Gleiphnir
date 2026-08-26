# `gleiphnir policy` — network policy (sbx parity)

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:106` `policy` alias `firewall-policy` (host, `mise run policy:*` → `vm/scripts/manage-policy.ps1`)
**Mise tasks:** `policy:init|ls|allow|deny|rm|check|reset|preset|dump` (`mise.toml:137`)

## Synopsis

```
gleiphnir policy init [balanced|open|locked]
gleiphnir policy ls [--wide] [--json] [--sandbox NAME]        # aliases: list,show,status
gleiphnir policy allow network <host|**|CIDR> [--port PORT] [--sandbox NAME]
gleiphnir policy deny network <host|CIDR> [--port PORT] [--sandbox NAME]
gleiphnir policy rm network --resource <host> [--id ID] [--sandbox NAME]  # aliases: remove,delete
gleiphnir policy check network <host|url> [--sandbox NAME]
gleiphnir policy reset [--force]
gleiphnir policy preset list|apply <preset>|diff
gleiphnir policy dump
```

This is the host entrypoint for VM policy (`sandbox-policy` + `ufw` + `mitmproxy` allowlist). In-container read-only view is `fen policy` (`docs/commands/fenrir-policy.md`).

| Sub | → `mise` | Flags / Args |
|---|---|---|
| `init [preset]` | `policy:init` | `balanced|open|locked|allow-all|deny-all` |
| `ls` | `policy:ls` | `--wide`, `--json`, `--sandbox` |
| `allow network <host>` | `policy:allow` | `--port`, `--sandbox` |
| `deny network <host>` | `policy:deny` | `--port`, `--sandbox` |
| `rm` | `policy:rm` | `--resource`, `--id`, `--sandbox` |
| `check network <host>` | `policy:check` | `--sandbox` |
| `reset` | `policy:reset` | `--force` |
| `preset list/apply/diff` | `policy:preset` | — |
| `dump` | `policy:dump` | — |

## Execution

Spec has `run:` on every leaf:
- `init`: `run: "[mise, run, policy:init]"`
- `ls`: `run: | #!/bin/sh` → `C_FLAG_WIDE`/`C_FLAG_JSON`/`C_FLAG_SANDBOX` → `exec mise run policy:ls -- $flag_args "$@"`
- `allow`/`deny`: `run: | #!/bin/sh` → `C_FLAG_SANDBOX`/`C_FLAG_PORT` → `exec mise run policy:allow -- "$@" $flag_args`
- etc.

→ `vm/scripts/manage-policy.ps1` → `ssh admin@VM "sudo sandbox-policy …"` → `/etc/sandbox/proxy-allowlist.txt` (domains) + `ufw` (CIDR).

## Examples

```bash
gleiphnir policy init balanced
gle policy ls --wide
gle policy allow network registry.npmjs.org
gle policy allow network "*.exa.ai"
gle policy allow network api.exa.ai --sandbox alice
gle policy check network https://api.exa.ai/search
gle policy rm network --resource evil.com --sandbox alice
gle policy reset --force
gle policy preset list
```

## See Also

- `docs/policy.md` (global) + `docs/policy/*.md` per subcommand (`allow`, `deny`, `ls`, `rm`, `check`, `reset`, `preset`, `init`)
- `docs/commands/fenrir-policy.md` (in-container)
- `vm/guest/bin/sandbox-policy:1`, `vm/guest/bin/sandbox-proxy:21`, `vm/scripts/manage-policy.ps1:1`
