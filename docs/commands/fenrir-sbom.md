# `fenrir sbom` — Software Bill of Materials — yolo: container|tools only

> **Yolo inside:** only `container|tools` allowed `container/files/fenrir:266` `vm|all` denied `deny_inside` — `vm` `dpkg/status` leaks host packages, use `gle sbom vm|all` on host.

**Spec (yolo):** `container/files/carapace/specs/fenrir.yaml:109` `sbom container|tools` only
**Binary:** `container/files/fenrir:266` `sandbox-sbom` read path

## Synopsis

```
# yolo inside (allowed)
fenrir sbom container|tools [--format spdx-json|cyclonedx] [--output <dir>]

# denied yolo — use host
gle sbom vm|all  # gle sbom container|tools|vm|all on host
```

| Subcommand | Description | Flags | Yolo |
|---|---|---|---|
| `fenrir sbom container` | SBOM for sandbox container image | `--format`, `--output` | **allowed** |
| `fenrir sbom tools` | SBOM for installed mise toolchains | `--format`, `--output` | **allowed** |
| `fenrir sbom vm` | SBOM for VM apt packages | `--format`, `--output` | **denied → `gle sbom vm`** |
| `fenrir sbom all` | Generate all SBOMs | `--format`, `--output` | **denied → `gle sbom all`** |

## Description (yolo)

Generate Software Bill of Materials via `sandbox-sbom` `vm/guest/bin/sandbox-sbom:1` (uses `syft` when available, fallback). Outputs SPDX 2.3 or CycloneDX 1.5 JSON. Host full `gle sbom` (`mise run sbom:*`) copies to `sbom/`.

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
