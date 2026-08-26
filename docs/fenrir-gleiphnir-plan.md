# Fenrir (`fen`) / Gleiphnir (`gle`) Carapace Plan

> Goal: `container/files/carapace/specs/` → **fenrir** (`fen`) for in-container work
> (delegating to `gdu`/`yazi` via mise, not hand-rolled tools) and VM/host side
> → **gleiphnir** (`gle`) wrapping `mise run …` tasks, all commands nested via
> `subcommands`.

## 0. Current State

- Container specs: `container/files/carapace/specs/sandbox-*.yaml:1` (7 files:
  `sandbox-firewall.yaml`, `sandbox-journal.yaml`, `sandbox-proxy.yaml`,
  `sandbox-sbom.yaml`, `sandbox-secrets.yaml`, `sandbox-tools.yaml`,
  `sandbox-user.yaml`) + `mise.yaml:1`. Each top-level `name: sandbox-*`
  with `aliases: [gle-*]` and flat `commands: [list, info, …]`.
- Install: `container/files/mise.toml:6-19` (`yazi`, no `gdu`) → shared volume
  `/opt/mise-shared` (`container/entrypoint.sh:10`) → deployed via
  `container/Containerfile:39` (`/etc/carapace/specs`) + linked by
  `container/files/mise.toml:77-82` task `dotfiles` → `$HOME/.config/carapace/specs`
  + shell init `container/files/dotfiles/bashrc:23-26` + `profile.ps1:30`.
- Guest binaries: `vm/guest/bin/sandbox-*` (8 scripts; same names as specs) →
  inlined into `vm/cloud-init/user-data.yaml.tpl:33-120` via
  `vm/scripts/template_userdata.py:17-38` → `/usr/local/bin/sandbox-*` on VM.
  Host `mise.toml:104-250` tasks proxy via `vm/scripts/manage-*.ps1` over SSH
  (`vm/guest/bin/sandbox-shell:1` login shell).
- Docs: `README.md:196` (carapace), `docs/architecture.md:60-88` (spec table +
  volume tooling).

## 1. Design Decisions

| Area | Decision |
|---|---|
| Container CLI | Single `fenrir.yaml` ( `name: fenrir`, `aliases: [fen]` ) with **nested** `commands[]` → `subcommands[]`. No remaining `sandbox-*.yaml`. Keep `mise.yaml` untouched. Implementation wrapper `container/files/fenrir` (bash) + symlink `fen` dispatches to `gdu`/`yazi`/existing impls. |
| VM/Host CLI | Single `gleiphnir.yaml` ( `name: gleiphnir`, `aliases: [gle]` ) nested to mirror `mise.toml` tasks. Stored at `vm/files/carapace/specs/gleiphnir.yaml` **and** mirrored to `container/files/carapace/specs/gleiphnir.yaml` for container visibility. Host wrapper `gleiphnir` shim (bash+pwsh) calls `mise run <task>`. |
| Tool delegation | `fenrir tools volumes` → `gdu /opt/mise-shared` etc.; `fenrir browse [<path>]` → `yazi`. Add `gdu = "latest"` and keep `yazi = "latest"` in `container/files/mise.toml`. No hand-rolled `du`/`ls`. |
| VM → mise | Every `gleiphnir` leaf runs `mise run <colon-task>` (e.g. `gleiphnir vm start` → `mise run vm:start`, `gleiphnir user add` → `mise run user:add`). Spec describes flags/args mapping to `USER=`, `IP=`, `TOOL=` env style already used by `vm/scripts/manage-*.ps1`. |
| Backward compat | Old `sandbox-*` commands remain as hidden aliases inside `fenrir` wrapper and old spec files deleted after migration; document migration. |
| Docs | Update `README.md`, `docs/architecture.md`, new `docs/commands.md` (full reference). |

## 2. Task Breakdown

### Task 1 — `container/files/mise.toml` : add `gdu`, ensure `yazi`

- Edit `container/files/mise.toml:6-19` `[tools]`:
  ```toml
  gdu = "latest"   # disk usage TUI for fenrir tools volumes
  yazi = "latest" # already present, keep (yasi alias)
  ```
- Optional: `yazi` already at `latest`; no `yasi` package exists — map `fenrir browse` to `yazi`.
- Verify: `mise ls-remote gdu` / syntax; `mise install --yes` warms.

### Task 2 — Container Fenrir CLI + spec

**Wrapper:** `container/files/fenrir` (install as `/usr/local/bin/fenrir` via `Containerfile` + `entrypoint.sh`, symlink `fen`):
```
fenrir tools list|info|clean|clean:all|volumes|browse
fenrir user add|remove|list
fenrir secrets list|set|remove|export|rotate
fenrir sbom container|tools|vm|all [--format] [--output]
fenrir journal [--last][--user][--session][--grep][--since][--failed][--cwd][--json][--follow]
fenrir proxy [--listen-port][--log-dir][--otel-endpoint]
fenrir firewall allow|deny|remove|enforce|list
fenrir browse [path]  → yazi
fenrir volumes        → gdu
```
- `tools volumes` delegates to `gdu /opt/mise-shared`, `$HOME`, `/work` (instead of `du -sb`).
- `browse` delegates to `yazi`.
- Fallback: if `gdu`/`yazi` missing, print `mise install` hint.
- Update `container/files/mise.toml:77-82` dotfiles task to link `fenrir` specs.

**Spec:** `container/files/carapace/specs/fenrir.yaml`:
```yaml
name: fenrir
aliases: [fen]
description: Fenrir sandbox CLI (in-container) — delegates to gdu/yazi
commands:
  - name: tools
    description: inspect and manage mise tool installs (gdu + yazi)
    subcommands:
      - {name: list, description: List all installed tools with disk usage}
      - {name: info, args: [{name: tool, dynamic: true}]}
      - {name: clean, args: [{name: tool, dynamic: true}]}
      - {name: clean:all, description: Remove all personal installs}
      - {name: volumes, description: Show volume mount info and disk usage (via gdu)}
      - {name: browse, description: Browse volumes with yazi, args: [{name: path, type: path}]}
  - name: user
    subcommands: [{name: add,...},{name: remove,...},{name: list,...}]
  - name: secrets …  (as before)
  - name: sbom … (with --format, --output)
  - name: journal … (flags)
  - name: proxy … (flags)
  - name: firewall …
    subcommands: [allow, deny, remove, enforce, list]
```
- Delete old `sandbox-*.yaml` (7 files) after creation.
- Keep `mise.yaml`.

### Task 3 — VM/Host Gleiphnir CLI + spec

**Wrapper:** `vm/files/gleiphnir` (bash) + `vm/files/gleiphnir.ps1` (pwsh shim) installed to host PATH and via `mise.toml` task `gleiphnir`:
- Each leaf maps: `gleiphnir vm start` → `mise run vm:start`, `gleiphnir user add alice --key-file …` → `mise run user:add USER=alice KEY=…`, etc.
- Cover all `mise.toml` tasks: `deps`, `install:deps`, `gen:key`, `image:*`, `network:*`, `vm:*`, `user:*`, `fw:*`, `container:*`, `sbom:*`, `tools:*`, `obs:*`, `secrets:*`, `smoke`, `up`/`down`.

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml` (+ copy to `container/files/carapace/specs/gleiphnir.yaml`):
```yaml
name: gleiphnir
aliases: [gle]
description: Gleiphnir host orchestration CLI (wraps mise tasks)
commands:
  - name: deps
  - name: vm
    subcommands: [{name: prepare},{name: start},{name: stop},{name: kill},{name: console},{name: ssh},{name: ssh:wait},{name: info},{name: clean},{name: clean:all}]
  - name: image
    subcommands: [download, info]
  - name: network
    subcommands: [up, down, status]
  - name: user
    subcommands: [{name: add, flags: [--key-file, --key], args: [username]}, {name: remove}, {name: list}]
  - name: fw
    subcommands: [allow, deny, remove, list, enforce]
  - name: container
    subcommands: [build, info]
  - name: sbom
    subcommands: [container, tools, vm, all]
  - name: tools
    subcommands: [list, info, clean, clean:all, volumes]
  - name: obs
    subcommands: [start, stop, status, open, deploy, clean]
  - name: secrets
    subcommands: [init, encrypt, decrypt, sync, list, status]
  - name: up
  - name: down
  - name: smoke
```

### Task 4 — Wiring / Deployment

- `Containerfile:39` add `COPY files/fenrir /usr/local/bin/fenrir` + symlink, `COPY files/carapace /etc/carapace`.
- `entrypoint.sh:10` ensure `fenrir` on PATH; `container/files/mise.toml` dotfiles task links `/etc/carapace/specs/*.yaml`.
- `vm/cloud-init/user-data.yaml.tpl:33-120` add `__FENRIR_CONTENT__`; `vm/scripts/template_userdata.py:17-38` add mapping to `container/files/fenrir`.
- Host `mise.toml` add optional `[tasks.gleiphnir]` helper or document `gle` alias → `mise run …` (spec alone suffices for completion; wrapper provides execution).
- Remove old `sandbox-*.yaml` and update `container/files/dotfiles/bashrc:23-26` comment.

### Task 5 — Documentation

- Update `README.md:196,211-225,242-266` (shell completion, task reference, repo layout) to `fenrir`/`fen` (container) vs `gleiphnir`/`gle` (host).
- Update `docs/architecture.md:60-88` spec table + volume tooling section.
- New `docs/commands.md` — full reference with examples:
  ```
  fenrir tools list
  fenrir tools volumes   # gdu
  fenrir browse /work    # yazi
  gleiphnir vm start
  gleiphnir user add USER=alice
  gle vm:ssh  (via alias gle)
  ```
- Update `docs/linux-local.md`, `docs/linux-server.md`, `docs/windows-*.md`, `docs/observability.md` where they reference `sandbox-*`.

### Task 6 — Verification

- `mise run deps` / `mise tasks ls` shows no regression.
- Inside container (podman): `fenrir --help`, `fen --help`, `fenrir tools volumes` invokes `gdu`, `fenrir browse` invokes `yazi`, `carapace fenrir` completion.
- On host: `gleiphnir --help`, `gle vm info`, `carapace gleiphnir` completion.
- `grep -R sandbox-` should only appear in deprecation notes/docs, not in active specs.

## Progress Tracking

- [ ] Task 1 — mise.toml gdu/yazi
- [ ] Task 2 — fenrir wrapper + spec (delete sandbox-*.yaml)
- [ ] Task 3 — gleiphnir wrapper + spec
- [ ] Task 4 — wiring (Containerfile, entrypoint, cloud-init, dotfiles)
- [ ] Task 5 — docs (README, architecture, commands.md)
- [ ] Task 6 — verify
