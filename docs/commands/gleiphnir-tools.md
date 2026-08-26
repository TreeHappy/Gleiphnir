# `gleiphnir tools` — volume tools (mise installs)

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:271` `tools` (host, `mise run tools:*` → `vm/scripts/manage-tools.ps1`)
**Mise tasks:** `tools:list|info|clean|clean:all|volumes|search` (`mise.toml:200`)

## Synopsis

```
gleiphnir tools list                          # list all tools (shared + personal)
gleiphnir tools info <tool>                   # TOOL=ripgrep
gleiphnir tools clean <tool>                  # remove personal install
gleiphnir tools clean:all                     # remove all personal
gleiphnir tools volumes                       # volume mount info
gleiphnir tools search QUERY [--source <src>] [--json]  # proxy-aware search
```

| Sub | → `mise` | Description |
|---|---|---|
| `list` | `tools:list` | `sandbox-tools list` via SSH |
| `info <tool>` | `tools:info` | `TOOL=…` |
| `clean <tool>` | `tools:clean` | personal only |
| `clean:all` | `tools:clean:all` |  |
| `volumes` | `tools:volumes` | `sandbox-tools volumes` |
| `search QUERY` | `tools:search` | `QUERY`, `--source npm|pypi|crates|go|github|exa|auto`, `--json` |

## Execution

- `list`/`info`/`clean`/`volumes`: `run: "[mise, run, tools:list]"` etc. (forwards `TOOL` positional).
- `search`: `run: | #!/bin/sh` → `C_FLAG_SOURCE`/`C_FLAG_JSON` → `exec mise run tools:search -- "$@" $flag_args` → `vm/scripts/manage-tools.ps1:35` `search` (checks policy for `registry.npmjs.org`, `pypi.org`, `api.exa.ai`, then `sandbox-tools search` via SSH).

## Examples

```bash
gleiphnir tools list
gle tools info ripgrep
gle tools clean ripgrep
gle tools volumes
gle tools search "http client" --source npm
gle tools search "vector db" --source exa --json
mise run tools:search -- "http client" --source pypi
```

In-container equivalent is `fen tools …` → `gdu`/`yazi` + `sandbox-tools` (see `docs/commands/fenrir-tools.md`).

## See Also

- `docs/commands/fenrir-tools.md`, `docs/tools-search.md`, `docs/policy.md`
- `vm/guest/bin/sandbox-tools:1`, `vm/scripts/manage-tools.ps1:1`
