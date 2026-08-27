# `gleiphnir vm` — VM lifecycle

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:26` `vm` (host, `mise run vm:*` → `vm/scripts/*.ps1`)
**Mise tasks:** `vm:prepare|start|stop|kill|console|ssh|ssh:wait|info|clean|clean:all` (`mise.toml:62`)

## Synopsis

```
gleiphnir vm prepare          # seed ISO + disks
gleiphnir vm start            # QEMU launch (creates bridge if needed on Linux)
gleiphnir vm stop             # graceful (QEMU monitor quit)
gleiphnir vm kill             # force-kill QEMU
gleiphnir vm console          # serial log (exit Ctrl-C)
gleiphnir vm ssh              # admin SSH
gleiphnir vm ssh:wait         # poll until reachable
gleiphnir vm info             # status, PID, network mode, disks
gleiphnir vm clean            # keep base image
gleiphnir vm clean:all        # remove base image too
gle vm start                  # alias gle → gleiphnir
```

| Sub | → `mise` | Notes |
|---|---|---|
| `prepare` | `vm:prepare` | seed ISO + disks (`vm/scripts/prepare-vm.ps1`, `template_userdata.py`) |
| `start` | `vm:start` | QEMU `qemu-system-x86_64 … -daemonize`, monitor `unix:qemu-monitor.sock` |
| `stop` | `vm:stop` | graceful |
| `kill` | `vm:kill` | force |
| `console` | `vm:console` | serial log |
| `ssh` | `vm:ssh` | admin SSH (`vm/scripts/ssh-admin.ps1`) |
| `ssh:wait` | `vm:ssh:wait` | poll (`wait-ssh.ps1`) |
| `info` | `vm:info` | status |
| `clean` | `vm:clean` | keep base |
| `clean:all` | `vm:clean:all` | all |

## Execution

Spec `run: "[mise, run, vm:start]"` etc. → shim `~/.config/carapace/bin/gleiphnir` → `mise run vm:start` → `vm/scripts/start-vm.ps1` → QEMU.

## Examples

```bash
gleiphnir vm prepare
gleiphnir vm start
gleiphnir vm ssh:wait && gleiphnir vm info
gleiphnir vm console
gleiphnir vm stop
gle vm clean:all
```

## See Also

- `docs/commands/gleiphnir-image.md`, `docs/commands/gleiphnir-network.md`
- `vm/scripts/start-vm.ps1:1`, `vm/scripts/prepare-vm.ps1:1`
- `docs/commands/README.md`
