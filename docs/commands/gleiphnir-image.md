# `gleiphnir image` — VM image management

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:8` `image` (host, `mise run image:*`)
**Mise tasks:** `image:download` | `image:info` (`mise.toml:39`)

## Synopsis

```
gleiphnir image download      # download Ubuntu cloud image (qcow2)
gleiphnir image info          # show downloaded image info
```

| Sub | → `mise` | Description |
|---|---|---|
| `download` | `image:download` | `vm/scripts/download-image.ps1` — fetch `resolute` cloudimg to `vm/images/` |
| `info` | `image:info` | `vm/scripts/image-info.ps1` — qemu-img info, size, backing |

## Execution

`run: "[mise, run, image:download]"` etc. via `carapace --run`.

## Examples

```bash
gleiphnir image download
gleiphnir image info
mise run image:download   # same underlying task
```

## See Also

- `docs/commands/gleiphnir-vm.md` (prepare uses image)
- `vm/scripts/download-image.ps1:1`, `vm/scripts/image-info.ps1:1`
- `config/sandbox.env:17` `UBUNTU_RELEASE=resolute`
