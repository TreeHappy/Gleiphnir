# `gleiphnir policy ls` — list active rules

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:125` `policy ls` (alias `list|show|status`)

## Synopsis

```
gleiphnir policy ls [--wide] [--json] [--sandbox NAME]
gle policy ls --wide
mise run policy:ls -- --wide
fenrir policy ls --wide   # inside container, read-only
```

## Description

Prints table:

```
POLICY           SOURCE   APPLIES TO          SUMMARY
local-policy     local    all                 network: 62 preset (balanced) + 3 allow, 1 deny
```

`--wide` expands: preset domains (head 100), global `allow`/`deny`, per-sandbox sections, proxy allowlist size (`/etc/sandbox/proxy-allowlist.txt`), and `ufw status verbose`. Impl: `vm/guest/bin/sandbox-policy:243` `cmd_ls` + `load_preset_domains` from `vm/guest/policy-presets/*.txt`.

## Examples

```bash
gle policy ls
gle policy ls --wide --sandbox alice
gle policy ls --json | jq .preset
```

## See Also

`docs/policy.md`, `docs/policy/allow.md`
