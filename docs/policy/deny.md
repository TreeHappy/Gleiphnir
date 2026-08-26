# `gleiphnir policy deny` — deny network host/CIDR

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:150`

## Synopsis

```
gleiphnir policy deny network <host|CIDR> [--port PORT] [--sandbox NAME]
```

## Description

Appends to `deny` list. Evaluated first — always wins over allow (SBX parity). Domain → proxy 403 (`vm/guest/bin/sandbox-proxy:34` `is_denied`), CIDR → `ufw deny out`.

## Examples

```bash
gle policy deny network evil.com
gle policy deny network ads.example.com
gle policy deny network 203.0.113.5
gle policy deny network api.exa.ai --sandbox bob   # per-sandbox block
```

Check still blocked: `gle policy check network evil.com` → `Denied: evil.com Reason: denied by global rule`.

## See Also

`docs/policy/allow.md`, `docs/policy/rm.md`
