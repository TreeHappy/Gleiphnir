# `fenrir secrets` — sandbox secrets (admin)

**Spec:** `container/files/carapace/specs/fenrir.yaml:84` `secrets` (admin only, `sandbox-secrets`)
**Binary:** `container/files/fenrir:263` `sandbox-secrets`

## Synopsis

```
fenrir secrets list
fenrir secrets set KEY=VALUE
fenrir secrets set KEY < file
fenrir secrets remove <key>
fenrir secrets export
fenrir secrets rotate <key>
```

## Description

Manage sandbox secrets stored in `/var/lib/sandbox/secrets.env` (admin-only). `list` shows key names, `set` adds/updates, `remove` deletes, `export` dumps `KEY=VALUE`, `rotate` generates a random 32-char value.

| Subcommand | Description |
|---|---|
| `fenrir secrets list` | Show key names (not values) |
| `fenrir secrets set KEY=VALUE` | Add/update (or `KEY < file`) |
| `fenrir secrets remove <key>` | Delete |
| `fenrir secrets export` | Dump all secrets as `KEY=VALUE` (admin only) |
| `fenrir secrets rotate <key>` | Generate random 32-char |

## Examples

```bash
fenrir secrets list
echo -n "s3cr3t" | fenrir secrets set MY_TOKEN
fenrir secrets set API_KEY=abc123
fenrir secrets export | grep MY_TOKEN
fenrir secrets rotate MY_TOKEN
```

## See Also

- Host secrets: `docs/commands/gleiphnir-secrets.md` (`gle secrets` → `age` encryption)
- Guest impl: `vm/guest/bin/sandbox-secrets:1`
