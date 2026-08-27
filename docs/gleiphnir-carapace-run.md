# Gleiphnir — Carapace `run:` Migration Plan

## Goal
Remove `container/files/gleiphnir` duplicate and make `vm/files/carapace/specs/gleiphnir.yaml` executable via `carapace --run` so the bash wrapper is no longer required.

## Context
- `container/files/gleiphnir:1` and `vm/files/gleiphnir:1` were identical bash wrappers mapping `gleiphnir <cmd> <sub>` → `mise run <task>`. `vm/files/gleiphnir.ps1:1` is the pwsh twin.
- `vm/files/carapace/specs/gleiphnir.yaml:1` previously had **no `run:`** (explicitly documented as "Specs never run" in `docs/commands.md:18`, `docs/policy.md:56`, `docs/architecture.md:66`). Execution was `gleiphnir` shim → `mise run` → `vm/scripts/*.ps1`.
- `container/Containerfile:41` copied `files/gleiphnir` into the image, and `vm/cloud-init/user-data.yaml.tpl:154` templated it to `/opt/sandbox/container/files/gleiphnir`. `vm/scripts/template_userdata.py:37` inlined `vm/files/gleiphnir` for both VM (`/usr/local/bin/gleiphnir`) and container sources.

## Decision
- **Keep** `vm/files/gleiphnir` + `vm/files/gleiphnir.ps1` as legacy fallback (host-only).
- **Delete** `container/files/gleiphnir` (host-only spec, container never needs host orchestration).
- **Add `run:` to every leaf** in `vm/files/carapace/specs/gleiphnir.yaml`:
  - Simple leaves: `run: "[mise, run, <task>]"` (alias mode, forwards `"$@"`).
  - Flag-bearing leaves: `run: | #!/bin/sh` with explicit `C_FLAG_*` handling (`--wide`, `--json`, `--sandbox`, `--port`, `--resource`, `--id`, `--force`, `--format`, `--output`, `--source`, `--key-file`/`--key` → `KEY=` for `user:add`).
- **Shim**: `carapace _carapace` generates `~/.config/carapace/bin/gleiphnir` → `carapace --run <spec> "$@"`. Host `PATH` must include `~/.config/carapace/bin`. `mise.toml:11` now lists `carapace = "latest"` to ensure host has `carapace`.

## Changes Implemented
1. `vm/files/carapace/specs/gleiphnir.yaml` — added `run:` (502 lines, ~150 new), quoted descriptions with `:` to fix YAML, added missing flags (`--sandbox`, `--port` for `policy allow/deny`, `--sandbox` for `check`).
2. `container/files/gleiphnir` — deleted.
3. `container/Containerfile:39-46` — removed `COPY files/gleiphnir` and `gle` symlink.
4. `vm/cloud-init/user-data.yaml.tpl:153-157` — removed container `gleiphnir` `write_files` block.
5. `mise.toml:11` — added `carapace = "latest"` (host dependency, was only in `container/files/mise.toml:18`).
6. Docs: `docs/commands.md:15-18,125,275`, `docs/architecture.md:32,66`, `docs/policy.md:56`, `README.md:216,300-310` — updated to reflect executable spec and removed container mirror.

## Verification
- `mise exec -- python3 -c "import yaml; yaml.safe_load(...)"` — YAML valid.
- `mise exec -- carapace --run vm/files/carapace/specs/gleiphnir.yaml --help` — shows 15 commands with `run`.
- `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 mise exec -- carapace --run vm/files/carapace/specs/gleiphnir.yaml deps` — executes `mise run deps` correctly.
- `carapace --run ... policy ls --help`, `user add --help`, `sbom container --help` — all resolve.

## Remaining / Next Steps
- Optionally remove `vm/files/gleiphnir` + `.ps1` entirely and rely solely on shim (current keeps them for backwards compat).
- Update `vm/scripts/manage-*.ps1` to also read `C_FLAG_*` env as fallback (currently shim script handles conversion; ps1 could also handle it for direct `mise run` without shim).
- Ensure `~/.config/carapace/bin` is on `PATH` in `docs/commands.md` host setup.
- Monitor `carapace --list | grep gleiphnir` after `carapace _carapace` to confirm shim creation.

## References
- Carapace `run` docs: `https://carapace-sh.github.io/carapace-bin/spec/run.html`, `shim.html`
- Spec source: `vm/files/carapace/specs/gleiphnir.yaml:1`
- Container build: `container/Containerfile:36`, `vm/cloud-init/user-data.yaml.tpl:94`
