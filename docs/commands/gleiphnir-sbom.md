# `gleiphnir sbom` — Software Bill of Materials

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:207` `sbom` (host, `mise run sbom:*` → `vm/scripts/sbom.ps1`)
**Mise tasks:** `sbom:container|tools|vm|all` (`mise.toml:183`)

## Synopsis

```
gleiphnir sbom container|tools|vm|all [--format spdx-json|cyclonedx] [--output <dir>]
```

| Sub | → `mise` | Flags |
|---|---|---|
| `sbom container` | `sbom:container` | `--format`, `--output` |
| `sbom tools` | `sbom:tools` | `--format`, `--output` |
| `sbom vm` | `sbom:vm` | `--format`, `--output` |
| `sbom all` | `sbom:all` | `--format`, `--output` |

## Description

Generate SBOMs via `sandbox-sbom` inside VM (uses `syft` if available, fallback to manifest). Copies results to host `sbom/` (`--output`). Host task does `ssh admin@VM "sandbox-sbom …"` + `scp` back.

| Task | Scope | What it scans |
|---|---|---|
| `sbom:container` | Container image | `localhost/sandbox:latest` via syft or `Containerfile` + `mise.toml` |
| `sbom:tools` | Mise toolchains | `/opt/mise-shared/data/installs/` |
| `sbom:vm` | VM apt packages | `/var/lib/dpkg/status` |
| `sbom:all` | All | Combined |

## Execution

`run: | #!/bin/sh` → `C_FLAG_FORMAT`/`C_FLAG_OUTPUT` → `exec mise run sbom:container -- "$@" $flag_args`

## Examples

```bash
gleiphnir sbom container --format cyclonedx --output /work/sbom
gle sbom all --format spdx-json
fen sbom all   # in-container, see docs/commands/fenrir-sbom.md
```

## See Also

- `docs/commands/fenrir-sbom.md`, `docs/commands/gleiphnir-tools.md`
- `vm/guest/bin/sandbox-sbom:1`, `vm/scripts/sbom.ps1:1`
