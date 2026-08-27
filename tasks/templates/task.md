# Task NNN — Title

> Template for `tasks/` entries. Copy to `tasks/NNN-slug.md`, fill, track via front-matter `status`.

```yaml
---
id: NNN
title: Title
status: todo # todo | doing | done
priority: high # high | medium | low
depends_on: []
owners: []
estimate: "1-2d"
---
```

## Goal / Non-Goals

- **Goal:** One sentence.
- **Non-Goals:** Explicitly out of scope.

## Current state (file:line refs)

- `path:line` — what exists and why it hurts lean/single-binary.

## Lean evaluation matrix (if applicable)

| Option | Deps | Size | DX | Firecracker fit | Verdict |
|---|---|---|---|---|---|
| A |  |  |  |  |  |
| B |  |  |  |  |  |

## Proposed change

- Files to touch (glob):
- CLI/config impact:
- Migration steps:

## Verification

```bash
# commands that prove done
shellcheck vm/scripts/*.sh
bash -n vm/scripts/*.sh
mise run deps
mise run up
mise run smoke
ssh admin@192.168.100.10 "sandbox-shell --help"
rg "IsWin|whpx|oscdimg" vm/scripts/ # expect 0 after 001+002
```

## Rollback

- Branch `chore/tasks-NNN`, revert commit if `smoke` fails.

## Checklist

- [ ] Branch created
- [ ] Files changed + shellcheck pass
- [ ] Docs updated (`README.md`, `docs/architecture.md`, etc.)
- [ ] `mise tasks ls` + `mise run deps` OK on Linux KVM
- [ ] Task marked `done`
