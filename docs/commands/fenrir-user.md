# `fenrir user` — sandbox user management

**Spec:** `container/files/carapace/specs/fenrir.yaml:55` `user` (in-container, delegates to `sandbox-user`)
**Binary:** `container/files/fenrir:260` `sandbox-user`

## Synopsis

```
fenrir user add <username> [--key-file <path> | --key "<pubkey>"]
fenrir user remove <username>
fenrir user list
```

## Description

Manage sandbox users on the VM (proxied via `sandbox-user` inside the container). `add` creates a `useradd -m -s /usr/local/bin/sandbox-shell` user, allocates `subuid`, writes `authorized_keys`, creates workspace `/srv/sandbox/<user>` and enables linger. `remove` deletes the user and home volume `gleiphnir-home-<user>`.

| Subcommand | Description | Flags |
|---|---|---|
| `fenrir user add <username>` | Create sandbox user | `--key-file <path>`, `--key "<pubkey>"` |
| `fenrir user remove <username>` | Remove user + home volume | — |
| `fenrir user list` | List users | — |

## Examples

```bash
fenrir user add alice --key-file ~/.ssh/id_ed25519.pub
fen user add bob --key "$(cat ~/.ssh/id_ed25519.pub)"
fenrir user list
fenrir user remove alice
```

## See Also

- Host equivalent: `docs/commands/gleiphnir-user.md` (`gle user add` → `mise run user:add`)
- Guest impl: `vm/guest/bin/sandbox-user:1`
- `docs/commands/fenrir-tools.md`
