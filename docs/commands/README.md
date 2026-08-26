# Commands — Index

This directory contains per-subcommand documentation split from `docs/commands.md`.

## Fenrir (`fen`) — in-container

- [`fenrir-tools.md`](fenrir-tools.md) — `fenrir tools list|info|clean|volumes|browse` + `fen volumes`/`fen browse` + `tools search`
- [`fenrir-user.md`](fenrir-user.md) — `fenrir user add|remove|list`
- [`fenrir-secrets.md`](fenrir-secrets.md) — `fenrir secrets list|set|remove|export|rotate`
- [`fenrir-sbom.md`](fenrir-sbom.md) — `fenrir sbom container|tools|vm|all`
- [`fenrir-journal.md`](fenrir-journal.md) — `fenrir journal --last --grep --since --failed --json --follow`
- [`fenrir-proxy.md`](fenrir-proxy.md) — `fenrir proxy --listen-port --log-dir --otel-endpoint`
- [`fenrir-firewall.md`](fenrir-firewall.md) — `fenrir firewall allow|deny|remove|enforce|list|ingress|egress`
- [`fenrir-policy.md`](fenrir-policy.md) — `fenrir policy init|ls|allow|deny|rm|check|reset|preset` (see also `docs/policy.md`)

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
