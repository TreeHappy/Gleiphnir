# `gleiphnir` — top-level tasks

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:341` (host, `mise run` via `run:`)
**Mise tasks:** `deps`, `up`, `down`, `smoke` (`mise.toml:28,286,302,281`)

## Synopsis

```
gleiphnir deps            # host dependency check
gleiphnir up              # full bring-up (deps→image→prepare→start→ssh:wait→obs:start)
gleiphnir down            # tear down (stop→network:down→obs:stop)
gleiphnir smoke           # quick smoke test (requires running VM)
```

| Gleiphnir | → `mise run` | Description |
|---|---|---|
| `gleiphnir deps` | `deps` | `vm/scripts/deps.ps1` — qemu, python/pycdlib, mise, pwsh, ip/iptables |
| `gleiphnir up` | `up` | `mise.toml:286` — `deps; image:download; vm:prepare; vm:start; vm:ssh:wait; obs:start?` |
| `gleiphnir down` | `down` | `mise.toml:302` — `vm:stop; network:down; obs:stop?` |
| `gleiphnir smoke` | `smoke` | `vm/scripts/smoke-test.ps1` — SSH, ufw, podman, image, volume, pwsh, RO, git/mise, firewall cycle |

## Execution

`run: "[mise, run, deps]"` etc. via `carapace --run`.

## Examples

```bash
gleiphnir deps
gleiphnir up        # or: mise run up
gleiphnir smoke
gleiphnir down
```

## See Also

- `docs/commands/gleiphnir-vm.md`, `docs/commands/gleiphnir-image.md`, `docs/commands/gleiphnir-network.md`
- `vm/scripts/deps.ps1:1`, `vm/scripts/smoke-test.ps1:1`
