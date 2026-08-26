# `gleiphnir policy` — Network Policy (sbx parity)

> Git-style one-short global description for the VM network policy engine.
> Controls egress (what a sandbox can reach) and ingress (who can reach the VM).
> Domain/wildcard rules go via the proxy allowlist (`/etc/sandbox/proxy-allowlist.txt`),
> IP/CIDR rules go via `ufw`. Presets mirror Docker Sandbox.

**Host spec:** `vm/files/carapace/specs/gleiphnir.yaml:79` (host only, `vm/scripts/` owns it — not copied into container).
**Guest impl:** `vm/guest/bin/sandbox-policy:1` + `vm/guest/bin/sandbox-firewall:1` (ingress/egress) + `vm/guest/bin/sandbox-proxy:21` (enforcement).
**Proxy:** `mitmproxy` on `8080`; containers get `http_proxy=http://$VM_IP:8080` (`vm/guest/bin/sandbox-shell:138`).
**Policy store:** `/var/lib/sandbox/policy.json` + `/etc/sandbox/policy-presets/*.txt` (`vm/guest/policy-presets/`).
**Mise tasks:** `policy:init|ls|allow|deny|rm|check|reset|preset` (`mise.toml:115`).

## Synopsis

```
gleiphnir policy init [balanced|open|locked]          # prompts if omitted
gleiphnir policy ls [--wide] [--sandbox NAME] [--json]
gleiphnir policy allow network <host|wildcard|**|CIDR> [--port PORT] [--sandbox NAME]
gleiphnir policy deny  network <host|CIDR> [--port PORT] [--sandbox NAME]
gleiphnir policy rm network --resource <host> [--sandbox NAME]
gleiphnir policy check network <host|host:port|url> [--sandbox NAME]
gleiphnir policy reset [--force]
gleiphnir policy preset list|apply <preset>|diff
gleiphnir policy dump           # dump sbx preset if sbx present
```

**Inside container (fen):** `fenrir policy …` → `sandbox-policy` read-only view (`container/files/fenrir:263`).

## Presets

| Preset | Outbound | Ingress | Use |
|--------|----------|---------|-----|
| `open` | `allow **` (all) | deny (ufw) | No restrictions — like `sbx policy allow network "**"` |
| `balanced` | deny + curated allowlist | deny | Dev defaults: npm, pypi, crates, go, nuget, maven, apt, mise, docker/gcr/quay, github/ghcr/gitlab, vscode, blob, exa.ai/api.exa.ai, AI APIs |
| `locked` | deny all (even APIs) | deny | Strict |

Seed: `vm/guest/policy-presets/balanced.txt:1` (60+ domains, mirrors Docker `Balanced` + Gleiphnir toolset).
Regen from Docker: `mise run policy:dump` (`vm/scripts/dump-docker-preset.ps1:1` runs `sbx policy ls --wide`).

## Subcommands (one-short, git-style)

* `init` — init preset (interactive prompt like `sbx policy init` if no arg) → `docs/policy/init.md`
* `ls` — list active rules (global + per-sandbox) → `docs/policy/ls.md`
* `allow` — add allow (domain → proxy, CIDR → ufw) → `docs/policy/allow.md`
* `deny` — add deny (deny wins) → `docs/policy/deny.md`
* `rm` — remove rule → `docs/policy/rm.md`
* `check` — test would-be-allowed → `docs/policy/check.md`
* `reset` — wipe store, re-init balanced → `docs/policy/reset.md`
* `preset` — list/apply/diff → `docs/policy/preset.md`

See `docs/policy/*.md` for full flags, examples (npm, pypi, github, exa.ai, per-sandbox `--sandbox`), and troubleshooting.

## Specs vs Execution

> **Gleiphnir spec is executable:** `vm/files/carapace/specs/gleiphnir.yaml` has `run:` on every leaf (`run: "[mise, run, ...]"` or `run: | #!/bin/sh` for flag-bearing commands). `carapace --run` / shim `~/.config/carapace/bin/gleiphnir` executes `mise run policy:*` → `vm/scripts/manage-policy.ps1` → `ssh admin@VM "sudo sandbox-policy …"` → `ufw` + proxy allowlist. `fenrir.yaml` remains completion-only (`fenrir` bash shim delegates to `gdu`/`yazi`/`sandbox-*`). Container `dotfiles` (`container/files/mise.toml:77` + `bashrc:23` `CARAPACE_SPEC_DIR=/etc/carapace/specs`) only loads `fenrir.yaml`+`mise.yaml`; `gleiphnir.yaml` stays on host `~/.config/carapace/specs/` via manual `ln -s` + shim `PATH` (`~/.config/carapace/bin`). Legacy `vm/files/gleiphnir` shim remains for fallback.

## See Also

- `docs/policy/*.md` — breakout per subcommand
- `docs/tools-search.md` — `gle tools search` proxy-aware
- `docs/commands.md` — index + `docs/commands/gleiphnir-policy.md` + `docs/commands/fenrir-policy.md` (per-command splits)
