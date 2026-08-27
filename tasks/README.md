# Tasks — Gleiphnir lean roadmap

Lean target: **single static binary `gleiphnir` like Docker `sbx` + only hosting tech (`qemu-system-x86_64`/`qemu-img` or `firecracker` + `podman` inside VM).**

Host after roadmap: `bash` + `qemu`/`firecracker` + `ip`/`iptables` + `python3` (`pycdlib` until native Go ISO) + `podman` (optional LGTM) + `otel-cli`. No `pwsh`. `mise` stays as task alias during transition. Guest/Container `pwsh` (`vm/guest/bin/sandbox-shell:126`) untouched.

## Ordering (DAG)

```
001-strip-windows
        │
        ▼
002-replace-pwsh-with-bash  (strict, keep otel-cli, keep python, keep mise)
        │
   ┌────┴────┐
   ▼         ▼
003-proxy  004-secrets  (parallel, decisions feed 005)
   └────┬────┘
        ▼
005-single-binary  (planning task, spec only — no code until 001-004 land)
```

## Task index

| ID | File | Title | Status | Depends |
|---|---|---|---|---|
| 001 | `tasks/001-strip-windows.md` | Strip Windows support (Linux-only KVM/bridge) | `done` | — |
| 002 | `tasks/002-replace-pwsh-with-bash.md` | Replace `vm/scripts/*.ps1` (`pwsh`) with `bash` (`set -euo pipefail`, `shellcheck`, keep `otel-cli`) | `todo` | 001 |
| 003 | `tasks/003-reevaluate-proxy.md` | Reevaluate proxy (`mitmproxy` → tinyproxy/squid or nftables) | `todo` | 002 |
| 004 | `tasks/004-reevaluate-secrets.md` | Reevaluate secret management (age → podman secret / host trust) | `todo` | 002 |
| 005 | `tasks/005-single-binary.md` | Single binary planning (`sbx`-like Go, `qemu` + `firecracker`) | `todo` | 001-004 |

Template: `tasks/templates/task.md`. Each task carries `status: todo|doing|done`, checklists, `file:line` refs, verification `mise run deps/up/smoke`, rollback branch `chore/tasks-NNN`.

## Lean guardrails

- Host deps frozen after `002`: `bash 5+`, `qemu-system-x86_64`, `qemu-img`, `iproute2`, `iptables`, `cloud-utils` or `pycdlib`+`python3`, `curl`/`git`/`ssh`, `mise`, `otel-cli`. No `pwsh`, no `whpx`, no `oscdimg`.
- Guest isolation stays: 3 volumes `vm/guest/bin/sandbox-shell:11-121` (`/srv/sandbox/<user>→/work`, `gleiphnir-home-<user>→/home/dev`, `sandbox-mise→/opt/mise-shared`), `podman --read-only --cap-drop ALL`.
- Long-running dev = `QEMU` persistent `DATA_DISK` `config/sandbox.env:20` ; AI agents = `Firecracker` ephemeral microVM (`virtiofs`/`vsock`, snapshot, no persistent volume).
- Verification after each task: `shellcheck vm/scripts/*.sh`, `bash -n vm/scripts/*.sh`, `mise run deps`, `mise run up && mise run smoke && ssh admin@192.168.100.10 true`, `rg "IsWin|whpx|oscdimg|\.ps1|pwsh" vm/scripts/ mise.toml` → 0.

## Running

```bash
ls tasks/*.md
cat tasks/001-strip-windows.md
# work a task
git checkout -b chore/tasks-001-strip-windows
# after done, mark status: done in front-matter
```

See also: `docs/architecture.md:1-140`, `README.md:2-115`, `mise.toml:1-311`.
