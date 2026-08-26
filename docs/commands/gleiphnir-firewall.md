# `gleiphnir fw` — firewall (deprecated → policy)

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:79` `fw` alias `firewall` (host, `mise run fw:*`)
**Mise tasks:** `fw:allow|deny|remove|list|enforce` (`mise.toml:116`)

## Synopsis

```
gleiphnir fw allow <ip>       # IP/CIDR → tcp/22 (compat)
gleiphnir fw deny <ip>        # deny all from IP
gleiphnir fw remove <ip>      # aliases: delete, unallow, undeny
gleiphnir fw list             # aliases: show, status
gleiphnir fw enforce          # alias: lockdown — drop bootstrap any→:22
gleiphnir firewall allow …    # alias for fw
```

| Sub | → `mise` | Args |
|---|---|---|
| `fw allow <ip>` | `fw:allow` | `IP=` (deprecated, use `policy allow network CIDR`) |
| `fw deny <ip>` | `fw:deny` |  |
| `fw remove <ip>` | `fw:remove` |  |
| `fw list` | `fw:list` |  |
| `fw enforce` | `fw:enforce` |  |

`vm/scripts/manage-firewall.ps1:11` accepts both `IP=1.2.3.4` and positional `1.2.3.4`.

## Execution

`run: "[mise, run, fw:allow]"` etc. → `vm/scripts/manage-firewall.ps1` → `ssh admin@VM "sudo sandbox-firewall allow …"` → `ufw`.

## Examples

```bash
gleiphnir fw allow 203.0.113.42
gle fw allow IP=203.0.113.42
gle fw list
gle fw enforce   # drop bootstrap rule → strict allow-list only
```

Deprecated — use `gle policy allow network` (`docs/policy.md`, `docs/commands/gleiphnir-policy.md`).

## See Also

- New: `docs/policy.md`, `docs/commands/gleiphnir-policy.md`, `docs/commands/fenrir-firewall.md`
- Impl: `vm/guest/bin/sandbox-firewall:1`, `vm/scripts/manage-firewall.ps1:1`
