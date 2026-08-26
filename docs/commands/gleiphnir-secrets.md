# `gleiphnir secrets` — secrets management

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:325` `secrets` (host, `mise run secrets:*` → `vm/scripts/secrets.ps1`)
**Mise tasks:** `secrets:init|encrypt|decrypt|sync|list|status` (`mise.toml:256`)

## Synopsis

```
gleiphnir secrets init        # generate age keypair for secrets encryption
gleiphnir secrets encrypt     # encrypt config/secrets.env → config/secrets.env.enc
gleiphnir secrets decrypt     # decrypt .enc → .env
gleiphnir secrets sync        # sync encrypted secrets to VM and decrypt there
gleiphnir secrets list        # list configured secret key names on VM
gleiphnir secrets status      # show encryption and sync status
```

| Sub | → `mise` | Description |
|---|---|---|
| `init` | `secrets:init` | `age` keypair |
| `encrypt` | `secrets:encrypt` |  |
| `decrypt` | `secrets:decrypt` |  |
| `sync` | `secrets:sync` | `scp` + VM decrypt |
| `list` | `secrets:list` | `sandbox-secrets list` via SSH |
| `status` | `secrets:status` |  |

## Execution

`run: "[mise, run, secrets:init]"` etc.

## Examples

```bash
gleiphnir secrets init
echo "EXA_API_KEY=… " >> config/secrets.env
gleiphnir secrets encrypt
gleiphnir secrets sync
gleiphnir secrets list
```

## See Also

- In-container: `docs/commands/fenrir-secrets.md` (`fen secrets` → `sandbox-secrets`)
- Impl: `vm/scripts/secrets.ps1:1`, `vm/guest/bin/sandbox-secrets:1`
- `docs/commands/gleiphnir-tools.md` (search uses secrets)
