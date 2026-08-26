# `gleiphnir policy preset` — manage presets

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:200` `policy preset`

## Synopsis

```
gleiphnir policy preset list
gleiphnir policy preset apply <balanced|open|locked>
gleiphnir policy preset diff
gle policy preset apply balanced
```

Alias for `policy init` with Docker parity (`sbx policy init balanced` / `sbx policy set-default`). `list` shows available + current (`balanced`). `diff` shows preset vs active (stub → calls `ls --wide`).

## Description

Presets live as `vm/guest/policy-presets/{balanced,open,locked}.txt`. `balanced.txt` is curated from Docker `Balanced` + Gleiphnir toolset + `exa.ai`. `open.txt` contains `**`. `locked.txt` empty (deny all). See `docs/policy.md` table.

To dump Docker’s live Balanced (if `sbx` installed): `mise run policy:dump` (`vm/scripts/dump-docker-preset.ps1:1` runs `sbx policy ls --wide` → `balanced-sbx-dump.txt`).

## Examples

```bash
gle policy preset list
gle policy preset apply locked
gle policy preset apply open
gle policy preset diff
```

## See Also

`docs/policy/init.md`, `docs/policy.md`
