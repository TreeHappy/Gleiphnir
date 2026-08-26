# `gleiphnir policy rm` — remove rule

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:160` `policy rm` (aliases `remove|delete`)

## Synopsis

```
gleiphnir policy rm network --resource <host|CIDR> [--sandbox NAME]
gleiphnir policy rm network --id <id>   # stub, prefer --resource
```

## Description

Removes matching entries from both `allow` and `deny` (global + per-sandbox). For CIDR also tries `ufw delete allow/deny out`. Re-syncs proxy allowlist.

## Examples

```bash
gle policy rm network --resource evil.com
gle policy rm network --resource 1.2.3.0/24
gle policy rm network --resource api.exa.ai --sandbox alice
```

## See Also

`docs/policy/allow.md`, `docs/policy/ls.md`
