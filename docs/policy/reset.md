# `gleiphnir policy reset` — reset policy

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:195` `policy reset`

## Synopsis

```
gleiphnir policy reset [--force]
```

## Description

Deletes `/var/lib/sandbox/policy.json` + `/etc/sandbox/proxy-allowlist.txt`, re-inits `balanced` (`vm/guest/bin/sandbox-policy:478` `cmd_reset`). Without `--force`, prompts `[y/N]` if TTY.

Matches `sbx policy reset` UX (prompted choice, `reset --force` for CI).

## Examples

```bash
gle policy reset
gle policy reset --force
```

## See Also

`docs/policy/init.md`, `docs/policy/ls.md`
