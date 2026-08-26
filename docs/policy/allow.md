# `gleiphnir policy allow` — allow network host/CIDR

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:140` `policy allow`

## Synopsis

```
gleiphnir policy allow network <host|wildcard|**|CIDR> [--port PORT] [--sandbox NAME]
```

`wildcard`: `*.github.com`, `**.example.com` (any depth), exact `github.com`, with optional `:port`. `**` = any host (open). CIDR/IP (`1.2.3.0/24`, `10.0.0.1`) routes to `ufw allow out`.

## Description

Adds to `/var/lib/sandbox/policy.json` (`global.allow` or `sandboxes[NAME].allow`), then syncs proxy allowlist + `ufw` if `is_ip_or_cidr` (`vehicle/guest/bin/sandbox-policy:156`). Deny still wins (checked first in `check`).

**Host proxy path:** `vm/scripts/manage-policy.ps1:60` `allow` → `sandbox-policy allow network ...` over SSH.

## Examples

```bash
# package managers
gle policy allow network registry.npmjs.org
gle policy allow network "*.npmjs.org"
gle policy allow network pypi.org
gle policy allow network files.pythonhosted.org
gle policy allow network crates.io
gle policy allow network proxy.golang.org
gle policy allow network nuget.org

# code hosts
gle policy allow network github.com
gle policy allow network "*.github.com"
gle policy allow network ghcr.io

# Exa AI (exa.ai websearch tool per https://exa.ai/)
gle policy allow network api.exa.ai
gle policy allow network "*.exa.ai"

# per-sandbox
gle policy allow network api.internal.acme.com --sandbox alice

# IP/CIDR via ufw
gle policy allow network 1.2.3.0/24
gle policy allow network 10.0.0.5 --port 443

# fenrir inside container
fen policy allow network registry.npmjs.org
```

## See Also

`docs/policy/deny.md`, `docs/policy/check.md`, `docs/policy.md`
