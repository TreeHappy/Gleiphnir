# `gleiphnir user` — sandbox user management

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:50` `user` (host, `mise run user:*`)
**Mise tasks:** `user:add|remove|list` (`mise.toml:103`)

## Synopsis

```
gleiphnir user add <user> [--key-file <path> | --key "<pubkey>"]
gleiphnir user remove <user>
gleiphnir user list
```

| Gleiphnir | → `mise` | Args |
|---|---|---|
| `gleiphnir user add <user> [--key-file|--key]` | `user:add` | `USER=`, `KEY=` (or positional `user` + `KEY=`) |
| `gleiphnir user remove <user>` | `user:remove` |  |
| `gleiphnir user list` | `user:list` |  |

Spec handles conversion: `--key-file /path` → `KEY=/path`, `--key "ssh-ed25519 …"` → `KEY="…"`. Underlying `vm/scripts/manage-user.ps1:14` accepts both `USER=alice`/`KEY=` and positional `alice`.

## Execution

- `add`: `run: | #!/bin/sh` → `exec mise run user:add -- "$@" $flag_args` where `flag_args` is `KEY=…` from `C_FLAG_KEY_FILE`/`C_FLAG_KEY`.
- `remove`/`list`: `run: "[mise, run, user:remove]"` etc.

→ `vm/scripts/manage-user.ps1` → `ssh admin@VM "sudo /usr/local/bin/sandbox-user add … --key-file /dev/stdin"` (base64 to avoid quoting).

## Examples

```bash
gleiphnir user add USER=alice KEY=~/.ssh/id_ed25519.pub
gle user add alice --key-file ~/.ssh/id_ed25519.pub
gleiphnir user add bob --key "ssh-ed25519 AAAAC3... bob@host"
gleiphnir user list
gleiphnir user remove alice   # also removes home volume gleiphnir-home-alice
mise run user:add USER=alice  # same underlying task
```

In-container equivalent: `fen user add alice --key-file …` → `sandbox-user` (see `docs/commands/fenrir-user.md`).

## See Also

- `docs/commands/fenrir-user.md`
- `vm/guest/bin/sandbox-user:1` (guest impl, home-volume cleanup)
- `vm/scripts/manage-user.ps1:1`
