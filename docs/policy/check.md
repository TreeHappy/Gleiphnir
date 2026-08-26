# `gleiphnir policy check` — test would-be-allowed

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:185` `policy check`

## Synopsis

```
gleiphnir policy check network <host|host:port|url> [--sandbox NAME]
```

Bare host defaults to `:443` (SBX parity). Accepts URL (`https://evil.com/path`), strips scheme/path.

## Description

Runs same engine as proxy (`vm/guest/bin/sandbox-policy:401` `cmd_check`): deny-first, then preset allowlist (`/etc/sandbox/policy-presets/balanced.txt`), then `global.allow`, then `sandboxes[NAME].allow`. Wildcard match via `domain_matches`. Used for preflight before `gle tools search`.

Exit `0` if Allowed, `1` if Denied (script-friendly).

## Examples

```bash
gle policy check network api.github.com:443
# Allowed: api.github.com:443
# Preset: balanced

gle policy check network evil.com
# Denied: evil.com
# Reason: no matching allow rule (default deny)

gle policy check network https://api.exa.ai/search
# Allowed: https://api.exa.ai/search

gle policy check network registry.npmjs.org --sandbox alice
```

Script: `if gle policy check network api.exa.ai >/dev/null; then exa search ...; fi`

## See Also

`docs/policy.md`, `docs/tools-search.md`
