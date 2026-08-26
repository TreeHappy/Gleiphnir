# `fenrir journal` — audit journal

**Spec:** `container/files/carapace/specs/fenrir.yaml:173` `journal` (`sandbox-journal`)
**Binary:** `container/files/fenrir:269` `sandbox-journal`

## Synopsis

```
fenrir journal [--last N] [--user USER] [--session ID] [--grep PATTERN]
               [--since 30s|5m|1h|7d] [--failed] [--cwd PATH] [--json] [--follow]
```

Flags-only command (no subcommands):

- `--last N` — Show last N commands (default: 20)
- `--user USER` — Filter by user
- `--session ID` — Filter by session ID
- `--grep PATTERN` — Search commands (regex)
- `--since 30s|5m|1h|7d` — Filter by time duration
- `--failed` — Only failed commands (`exit_code != 0`)
- `--cwd PATH` — Filter by working directory prefix
- `--json` — Output raw JSON (one object per line)
- `--follow` — Tail new entries (like `tail -f`)

## Description

Query the agent audit journal at `/var/log/sandbox/journal-<user>.jsonl`. Each entry is `{timestamp, event, user, session_id, command, cwd, exit_code, duration_ms}`. Written by `container/files/dotfiles/bashrc:51` `__sandbox_journal_log` via `DEBUG` trap + `PROMPT_COMMAND`.

## Examples

```bash
fenrir journal --last 50
fen journal --grep git --since 1h --failed
fen journal --json | jq .
fenrir journal --follow --last 20
```

## See Also

- Impl: `vm/guest/bin/sandbox-journal:1`
- `docs/commands/fenrir-tools.md`
