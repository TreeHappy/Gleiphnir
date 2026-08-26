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
- [x] Guest: `sandbox-policy`, `sandbox-firewall` ingress/egress, `sandbox-proxy` filter, presets `balanced/open/locked`
- [ ] Host: `manage-policy.ps1`, `dump-docker-preset.ps1`, `manage-tools` search
- [ ] Orchestration: `mise.toml` policy:* tasks
- [ ] Wrappers: `vm/files/gleiphnir` + `vm/files/gleiphnir.ps1` + `container/files/fenrir` policy verbs
- [ ] Specs: host `gleiphnir.yaml` policy tree, host-only, remove container mirror
- [ ] Wiring: `vm/scripts/template_userdata.py` + `vm/cloud-init/user-data.yaml.tpl` inlines
- [ ] Docs: `docs/policy*` split, `docs/commands.md`, `README.md`, `docs/architecture.md`
- [ ] Presets: seed from `sbx policy ls` via `dump-docker-preset.ps1`
- [ ] Verification: `mise tasks ls`, `carapace`, `sandbox-policy check`, `gle policy ls --wide`, `gle tools search`

## Implementation Notes
- Policy store: `/var/lib/sandbox/policy.json` (global.allow/deny, sandboxes map), proxy allowlist: `/etc/sandbox/proxy-allowlist.txt`
- `sandbox-firewall` now supports `ingress allow|deny|remove` and `egress allow|deny|remove|enforce` with `--port/--proto`
- `sandbox-proxy` addon adds `request()` check: deny wins, then allowlist (`**` = allow all), logs `egress_denied` to `/var/log/sandbox/proxy-*.jsonl`
- Carapace specs must stay on host (`vm/...`) — container `dotfiles` task links only `fenrir.yaml` + `mise.yaml` to `/etc/carapace/specs`
