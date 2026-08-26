# `fenrir sbom` — Software Bill of Materials

**Spec:** `container/files/carapace/specs/fenrir.yaml:109` `sbom` (`sandbox-sbom`)
**Binary:** `container/files/fenrir:266` `sandbox-sbom`

## Synopsis

```
fenrir sbom container|tools|vm|all [--format spdx-json|cyclonedx] [--output <dir>]
```

| Subcommand | Description | Flags |
|---|---|---|
| `fenrir sbom container` | SBOM for sandbox container image | `--format`, `--output` |
| `fenrir sbom tools` | SBOM for installed mise toolchains | `--format`, `--output` |
| `fenrir sbom vm` | SBOM for VM apt packages | `--format`, `--output` |
| `fenrir sbom all` | Generate all SBOMs | `--format`, `--output` |

## Description

Generate Software Bill of Materials via `sandbox-sbom` (uses `syft` when available, fallback to manifest). Outputs SPDX 2.3 or CycloneDX 1.5 JSON. Host side is `gle sbom` (`mise run sbom:*`) which copies results to `sbom/` on host.

## Examples

```bash
fenrir sbom container --format cyclonedx --output /work/sbom
fen sbom tools --format spdx-json
fen sbom all --format cyclonedx
```

## See Also

- Host: `docs/commands/gleiphnir-sbom.md`
- Impl: `vm/guest/bin/sandbox-sbom:1`, `vm/scripts/sbom.ps1:1`
- `docs/commands/fenrir-tools.md`
