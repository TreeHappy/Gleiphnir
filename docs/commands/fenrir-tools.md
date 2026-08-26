# `fenrir tools` — mise installs (via `gdu`/`yazi`)

**Spec:** `container/files/carapace/specs/fenrir.yaml:5` `tools` (in-container, `gdu`/`yasi`)
**Binary:** `/usr/local/bin/fenrir` (`fen` → `fenrir` symlink) `container/files/fenrir:132` `cmd_tools`

## Synopsis

```
fenrir tools list
fenrir tools info <tool>
fenrir tools clean <tool>
fenrir tools clean:all
fenrir tools volumes [--gdu|--no-gdu]
fenrir tools browse [path]
fenrir tools search QUERY [--source npm|pypi|crates|go|github|exa] [--json]
fenrir volumes                          # alias for tools volumes
fenrir browse [path]                    # top-level yazi
```

## Description

Inspect and manage `mise` tool installs. `gdu` is used for disk usage, `yazi`/`yasi` for browsing. Delegates to `sandbox-tools` when present, otherwise uses `du` fallback.

| Subcommand | Delegation | Example |
|---|---|---|
| `fenrir tools list` | `sandbox-tools list` or fallback `du` | `fen tools list` |
| `fenrir tools info <tool>` | `sandbox-tools info` | `fen tools info ripgrep` |
| `fenrir tools clean <tool>` | `sandbox-tools clean` (personal only) | `fen tools clean ripgrep` |
| `fenrir tools clean:all` | `sandbox-tools clean:all` | `fen tools clean:all` |
| `fenrir tools volumes [--gdu|--no-gdu]` | **`gdu`** (`/opt/mise-shared`, `$HOME`, `/work`) — interactive TUI if tty, else `gdu --non-interactive` → fallback `du -sb` | `fen tools volumes` <br> `fen tools volumes --gdu` |
| `fenrir tools browse [path]` | **`yazi`/`yasi`** | `fen tools browse /opt/mise-shared` |
| `fenrir volumes` | alias for `tools volumes` | `fen volumes` |
| `fenrir browse [path]` | top-level `yazi` | `fen browse /work` |

> `container/files/mise.toml:15-16` ensures `yazi = "latest"` and `gdu = "latest"` are pre-installed into the shared volume (`sandbox-mise` → `/opt/mise-shared`, warmed by `vm/guest/lib/build-container.sh:14`).

## Search (proxy-aware)

Flags: `--source npm|pypi|crates|go|github|exa|auto` `--json`

```bash
fenrir tools search "http client" --source npm
fen tools search "vector db" --source exa
```

See `docs/tools-search.md` and `docs/commands/gleiphnir-tools.md` for host side (`gle tools search`).

## See Also

- `docs/commands/fenrir-policy.md`
- `docs/commands/README.md` (overview)
- `container/files/fenrir:72` `run_gdu` / `run_yazi`
