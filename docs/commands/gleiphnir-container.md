# `gleiphnir container` — sandbox container image

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:199` `container` (host, `mise run container:*`)
**Mise tasks:** `container:build|info` (`mise.toml:174`)

## Synopsis

```
gleiphnir container build     # build localhost/sandbox:latest inside running VM
gleiphnir container info      # show image info from inside VM
```

| Sub | → `mise` | Description |
|---|---|---|
| `build` | `container:build` | `vm/scripts/container-build.ps1` → `ssh admin@VM "sudo /usr/local/lib/sandbox/build-container.sh"` (podman build + warm `sandbox-mise`) |
| `info` | `container:info` | `vm/scripts/container-info.ps1` |

## Execution

`run: "[mise, run, container:build]"` etc.

## Examples

```bash
gleiphnir container build
gleiphnir container info
mise run container:build   # same
```

## See Also

- `vm/guest/lib/build-container.sh:1`, `vm/scripts/container-build.ps1:1`
- `container/Containerfile:1`, `docs/commands/gleiphnir-vm.md`
