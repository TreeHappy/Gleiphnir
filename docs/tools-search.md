# `gle tools search` — proxy-aware search (npm/pypi/github/exa)

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:215` `tools search` (host, `vm/scripts/manage-tools.ps1` → `vm/guest/bin/sandbox-tools:260` `cmd_search`)

## Synopsis

```
gleiphnir tools search QUERY [--source npm|pypi|crates|go|github|exa|auto] [--json]
gle tools search "http client" --source npm
mise run tools:search -- "http client" --source exa
fen tools search "http client"   # inside container
```

## Description

Searches across registries, respecting egress policy:

1. **Policy check** (`sandbox-policy check network <registry>`) — prints `allowed`/`BLOCKED` hint per host (`registry.npmjs.org`, `pypi.org`, `crates.io`, `proxy.golang.org`, `api.github.com`, `api.exa.ai`). Requires `gle policy allow network <host>` if blocked.
2. **Sources:**
   - `mise registry | grep -i` — local, always allowed
   - `npm search/view` — `registry.npmjs.org` (needs allow)
   - `pypi` — `https://pypi.org/pypi/<query>/json` via `curl`
   - `crates/go` — future via `curl` (stub)
   - `github` — `gh search repos` via `api.github.com` (needs `gh` auth + allow)
   - `exa.ai` — `https://api.exa.ai/search` (`EXA_API_KEY` via `gle secrets set EXA_API_KEY=…` + `secrets:sync`; `exa.ai` docs: https://exa.ai/)

Impl: `vm/guest/bin/sandbox-tools` `cmd_search` runs each source conditionally; `EXA_API_KEY` injected from `/var/lib/sandbox/secrets.env` → container `-e` (`vm/guest/bin/sandbox-shell:126`).

## Examples

```bash
gle tools search "http client"
gle tools search "vector db" --source exa
gle tools search requests --source pypi --json
fen tools search "clap" --source crates
```

Blocked hint:
```
registry.npmjs.org: BLOCKED (gle policy allow network registry.npmjs.org)
```

## See Also

`docs/policy.md`, `docs/policy/check.md`, `docs/policy/allow.md`
