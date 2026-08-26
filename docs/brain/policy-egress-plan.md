# Policy / Egress-Ingress Plan (sbx policy parity)

> Living plan for egress/ingress VM commands + sensible presets.
> Mirrors Docker Sandbox Balanced preset + Gleiphnir toolset + Exa AI.
> See `docs/fenrir-gleiphnir-plan.md` for original carapace split.

## Goals
- `gleiphnir policy init|ls|allow|deny|rm|check|reset` like `sbx policy` (global + `--sandbox NAME` per-sandbox).
- Presets: `open` (**), `balanced` (deny + ~60 domains), `locked` (deny all). Default `balanced` on first `gle up` with interactive prompt.
- Enforce via dual layer: domain/wildcard → `sandbox-proxy` mitmproxy allowlist (`/etc/sandbox/proxy-allowlist.txt`), CIDR/IP → `ufw` (`sandbox-firewall` ingress/egress).
- Sensible Balanced domains: npm, pypi, crates, go, nuget, maven, rubygems, apt, mise, docker/gcr/quay, github/ghcr/gitlab, vscode blob, AI (openai/anthropic), *exa.ai/api.exa.ai*.
- Host-only Carapace spec `vm/files/carapace/specs/gleiphnir.yaml`; container `fenrir.yaml` stays, remove `container/files/carapace/specs/gleiphnir.yaml` mirror. `vm/scripts/` owns host spec.
- Docs split: `docs/policy.md` global one-short git-style, breakout `docs/policy/*.md` per subcommand + `docs/tools-search.md`.
- `gle tools search <q>` proxy-aware search over package managers + GitHub + Exa.

## Progress Tracking
- [x] Guest: `sandbox-policy`, `sandbox-firewall` ingress/egress, `sandbox-proxy` filter, presets `balanced/open/locked` — done `e637426`+`d410038`
- [x] Host: `manage-policy.ps1`, `dump-docker-preset.ps1`, `manage-tools` search — done `7dbe058`
- [x] Orchestration: `mise.toml` policy:* tasks — done `7dbe058`
- [x] Wrappers: `vm/files/gleiphnir` + `vm/files/gleiphnir.ps1` + `container/files/fenrir` policy verbs — done `7dbe058`
- [x] Specs: host `gleiphnir.yaml` policy tree, host-only, remove container mirror — done `7dbe058`
- [x] Wiring: `vm/scripts/template_userdata.py` + `vm/cloud-init/user-data.yaml.tpl` inlines — done `7dbe058`+`d410038`
- [x] Docs: `docs/policy*` split, `docs/commands.md`, `README.md`, `docs/architecture.md` — done `7dbe058`
- [x] Presets: seed from `sbx policy ls` via `dump-docker-preset.ps1` — done `vm/guest/policy-presets/balanced.txt:1` covers npm/pypi/crates/go/nuget/maven/apt/mise/docker, github/ghcr, vscode/exa.ai (`api.exa.ai`); dump helper seeds from live sbx
- [x] Verification: `mise tasks ls` shows `policy:*`+`tools:search`, `bash -n` ok, `LC_ALL=C sort -u` fix verified, `sandbox-policy check api.exa.ai`→Allowed — done `d410038`

**Status 2026-08-26: COMPLETE.** All egress/ingress VM commands + sensible presets (like Docker `Balanced` + Gleiphnir toolset + `exa.ai` https://exa.ai/) + host-only `vm/files/carapace/specs/gleiphnir.yaml` + git-style docs split implemented. Ready to remove plan.

## Implementation Notes
- Policy store: `/var/lib/sandbox/policy.json` (global.allow/deny, sandboxes map), proxy allowlist: `/etc/sandbox/proxy-allowlist.txt`
- `sandbox-firewall` now supports `ingress allow|deny|remove` and `egress allow|deny|remove|enforce` with `--port/--proto`
- `sandbox-proxy` addon adds `request()` check: deny wins, then allowlist (`**` = allow all), logs `egress_denied` to `/var/log/sandbox/proxy-*.jsonl`
- Carapace specs must stay on host (`vm/...`) — container `dotfiles` task links only `fenrir.yaml` + `mise.yaml` to `/etc/carapace/specs`
