# Commands — Index

This directory contains per-subcommand documentation split from `docs/commands.md`.

## Fenrir (`fen`) — in-container — yolo-safe (read-only, see `container/files/fenrir:18`)

- [`fenrir-tools.md`](fenrir-tools.md) — `fenrir tools list|info|clean|volumes|browse` + `fen volumes`/`fen browse` + `tools search` — **allowed yolo**
- [`fenrir-sbom.md`](fenrir-sbom.md) — `fenrir sbom container|tools` — **yolo: container/tools only, `vm|all` denied inside (use `gle sbom`)**
- [`fenrir-journal.md`](fenrir-journal.md) — `fenrir journal --last --grep --since --failed --json --follow` — **allowed read-only yolo**
- [`fenrir-policy.md`](fenrir-policy.md) — `fenrir policy ls|check` — **yolo read-only; `init|allow|deny|rm|reset|preset` denied inside (use `gle policy`)** (see also `docs/policy.md`)
- [`fenrir-user.md`](fenrir-user.md) — **denied yolo** — use `gle user add|remove|list` on host (`vm/guest/bin/sandbox-user:1`)
- [`fenrir-secrets.md`](fenrir-secrets.md) — **denied yolo** — use `gle secrets sync|list|status` on host (`vm/guest/bin/sandbox-secrets:1`, `sandbox-shell:123` injects via env)
- [`fenrir-firewall.md`](fenrir-firewall.md) — **denied yolo** — use `gle fw` / `gle policy` on host (`vm/guest/bin/sandbox-firewall:1`, `sandbox-policy:1`)
- [`fenrir-proxy.md`](fenrir-proxy.md) — **denied yolo** — host `gle obs` / `vm/guest/bin/sandbox-proxy:1` only

## Gleiphnir (`gle`) — host / VM

- [`gleiphnir-top-level.md`](gleiphnir-top-level.md) — `gleiphnir deps|up|down|smoke`
- [`gleiphnir-image.md`](gleiphnir-image.md) — `gleiphnir image download|info`
- [`gleiphnir-network.md`](gleiphnir-network.md) — `gleiphnir network up|down|status`
- [`gleiphnir-vm.md`](gleiphnir-vm.md) — `gleiphnir vm prepare|start|stop|kill|console|ssh|ssh:wait|info|clean|clean:all`
- [`gleiphnir-user.md`](gleiphnir-user.md) — `gleiphnir user add|remove|list`
- [`gleiphnir-firewall.md`](gleiphnir-firewall.md) — `gleiphnir fw allow|deny|remove|list|enforce` (deprecated)
- [`gleiphnir-policy.md`](gleiphnir-policy.md) — `gleiphnir policy init|ls|allow|deny|rm|check|reset|preset|dump` (see also `docs/policy.md` + `docs/policy/*.md`)
- [`gleiphnir-container.md`](gleiphnir-container.md) — `gleiphnir container build|info`
- [`gleiphnir-sbom.md`](gleiphnir-sbom.md) — `gleiphnir sbom container|tools|vm|all`
- [`gleiphnir-tools.md`](gleiphnir-tools.md) — `gleiphnir tools list|info|clean|volumes|search` (see `docs/tools-search.md`)
- [`gleiphnir-obs.md`](gleiphnir-obs.md) — `gleiphnir obs start|stop|status|open|deploy|clean`
- [`gleiphnir-secrets.md`](gleiphnir-secrets.md) — `gleiphnir secrets init|encrypt|decrypt|sync|list|status`

## Carapace

- [`carapace.md`](carapace.md) — shell completion + executable specs (`run:`), shim `~/.config/carapace/bin/gleiphnir`

## Index

- [`../commands.md`](../commands.md) — top-level overview (this directory is the split view)
