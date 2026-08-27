# `fenrir secrets` — DENIED yolo inside (host `gle secrets` only)

> **Yolo: `fen secrets` denied inside container** `container/files/fenrir:263 deny_inside` — secrets are injected as env vars `vm/guest/bin/sandbox-shell:123` `COMMON_ARGS -e` from `/var/lib/sandbox/secrets.env:7` `chmod 600`. Use `gle secrets` on host (`vm/files/carapace/specs/gleiphnir.yaml:470` → `mise run secrets:*` `vm/scripts/secrets.ps1:1` `age -r` `scp`) or `ssh admin → sudo sandbox-secrets:1`. Inside container `env | grep SECRET` already, no `fen secrets` needed.

**Spec (yolo):** removed from `container/files/carapace/specs/fenrir.yaml:84` (was `secrets`); host keeps `vm/files/carapace/specs/gleiphnir.yaml:470`.
**Binary:** `container/files/fenrir:263 deny_inside`, host `vm/guest/bin/sandbox-secrets:1` privileged `require_root:30`.

## Synopsis (host)

```
gle secrets init|encrypt|decrypt|sync|list|status  # host
sudo sandbox-secrets list|set|remove|export|rotate  # VM admin
```

## Description (host)

Host `gle secrets` manages `config/secrets.env` `age` encrypted `*.enc` `.gitignore:20` and syncs to `/var/lib/sandbox/secrets.env` `0600` via `scp` `secrets.ps1:89` `HOST_SSH_FORWARD_PORT=2233` `config/sandbox.env:50`. Inside container secrets appear as `env` `sandbox-shell:130`, not via `fen`.

## Examples (host, not yolo)

```bash
# host
gle secrets list
gle secrets sync  # scp → VM
ssh admin@192.168.100.10 "sudo sandbox-secrets list"
ssh alice@192.168.100.10 env | grep MY_TOKEN  # inside sees env, not fen
```

## See Also

- Host secrets: `docs/commands/gleiphnir-secrets.md` (`gle secrets` → `age` encryption)
- Guest impl: `vm/guest/bin/sandbox-secrets:1`
- Yolo: inside `fen secrets` denied `container/files/fenrir:263`
