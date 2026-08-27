# `fenrir user` — DENIED yolo inside (host `gle user` only)

> **Yolo: `fen user` denied inside** `container/files/fenrir:260 deny_inside` — `useradd -m -s sandbox-shell` `vm/guest/bin/sandbox-user:1` `subuid 100000` `Match User *,!admin` `vm/cloud-init/user-data.yaml.tpl:218` are host-only privileged. Use `gle user add|remove|list` on host (`vm/files/carapace/specs/gleiphnir.yaml:66` → `mise run user:*` → `ssh admin → sudo sandbox-user`).

**Spec (yolo):** removed from `container/files/carapace/specs/fenrir.yaml:55`; host keeps `vm/files/carapace/specs/gleiphnir.yaml:66`.
**Binary:** `container/files/fenrir:260 deny_inside`, host `vm/guest/bin/sandbox-user:1`.

## Synopsis (host)

```
gle user add <username> [--key-file <path> | --key "<pubkey>"]  # host
gle user remove <username>
gle user list
```

## Description (host)

Host `gle user` manages `useradd -m -s /usr/local/bin/sandbox-shell:201` on VM via `ssh admin` `sudo sandbox-user`. Allocates `subuid 100000:165536` `user-data.yaml.tpl:256`, writes `authorized_keys`, workspace `/srv/sandbox/<user>` `sandbox-shell:11`, volume `gleiphnir-home-<user>` `sandbox-shell:12`. **Denied yolo** `container/files/fenrir:260`.

| Subcommand | Description | Flags | Yolo |
|---|---|---|---|
| `fenrir user add <username>` | Create sandbox user (host) | `--key-file`, `--key` | **denied → `gle user add`** |
| `fenrir user remove <username>` | Remove user + home volume | — | **denied → `gle user remove`** |
| `fenrir user list` | List users | — | **denied → `gle user list`** |

## Examples (host, not yolo)

```bash
gle user add USER=alice KEY=~/.ssh/id_ed25519.pub
gle user list
gle user remove USER=alice
```

## See Also

- Host: `docs/commands/gleiphnir-user.md` (`gle user add` → `mise run user:add`)
- Guest impl: `vm/guest/bin/sandbox-user:1`
- Yolo: inside `fen user` denied `container/files/fenrir:260`
