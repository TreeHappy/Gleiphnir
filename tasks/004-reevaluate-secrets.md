---
id: 004
title: Reevaluate secret management (age file → podman secret / host trust)
status: todo
priority: medium
depends_on: [002]
estimate: "1d"
branch: chore/tasks-004-secrets
---

## Goal / Non-Goals

- **Goal:** Make secrets lean for bash host + single binary + two profiles: (1) long-running dev (persistent volumes `vm/guest/bin/sandbox-shell:11-121` `gleiphnir-home-*` + `sandbox-mise`) where secrets survive, (2) AI agent Firecracker microVMs ephemeral where secrets do **not** persist. Keep `python`+`mise` per confirm, keep `otel-cli`, host = `bash`, target single binary `005` embeds lean without external `age` bin if possible.
- **Non-Goals:** No Vault service, no proxy decision (`003`), no binary impl (`005`).

## Current state (file:line refs)

- Host: `config/sandbox.env:99-104` `SECRETS_ENABLED=false` + `SECRETS_AGE_PUBKEY=` (age `age1...`), `vm/scripts/secrets.ps1:1-133` (bash port in `002`) `encrypt` `age -r $pubKey -o $SECRETS_ENC` `vm/scripts/secrets.ps1:47`, `decrypt` `age -d -i ~/.ssh/gleiphnir_secrets_key` `vm/scripts/secrets.ps1:59,65`, `sync` `scp $SECRETS_PLAIN admin@127.0.0.1:/var/lib/sandbox/secrets.env` `vm/scripts/secrets.ps1:89` (+ `NETWORK_MODE=user` branch `vm/scripts/secrets.ps1:86`), `chmod 600 + chown root` `vm/scripts/secrets.ps1:93`, `list/status` `vm/scripts/secrets.ps1:96-116`. Needs `age` dep `vm/scripts/secrets.ps1:27-32` `Test-AgeInstalled` (`winget` note gone after `001`). Plain `config/secrets.env` gitignored `.gitignore:20` but `*.enc` also `21`.
- Guest: `vm/guest/bin/sandbox-secrets:1-131` (`list/set/remove/export/rotate` `vm/guest/bin/sandbox-secrets:45-120`, `chmod 600` `vm/guest/bin/sandbox-secrets:41`), injected as `while read line; COMMON_ARGS+=(-e "$line")` `vm/guest/bin/sandbox-shell:123-130` if `secrets-enabled` marker `vm/scripts/secrets.ps1:93` touched.
- `mise.toml:256-279` `secrets:init|encrypt|decrypt|sync|list|status` → `vm/scripts/secrets.*.sh` after `002`.
- Issues: `age` not in `vm/scripts/deps.sh` (bash port) `vm/scripts/deps.ps1:22-59`, key `~/.ssh/gleiphnir_secrets_key` manual, global file `/var/lib/sandbox/secrets.env` (no per-user/per-sandbox `--sandbox` scoping like `sandbox-policy:313` but policy has it), `podman secret` unused, Firecracker snapshot would leak `/var/lib/sandbox` file, long-running dev needs per-user persistence not global.

## Lean evaluation

| Option | Host deps | Guest mechanism | Per-user/vol | Firecracker ephemeral | Verdict |
|---|---|---|---|---|---|
| **Keep age file** `vm/scripts/secrets.ps1:47` `age -r` | `age` bin | `-e` `vm/guest/bin/sandbox-shell:126` | global only | file persists on `DATA_DISK` `config/sandbox.env:20` → leak | baseline, not lean |
| **A: Drop age, trust host FS+SSH** | none (plaintext `config/secrets.env` `0600` + `scp` over SSH `vm/scripts/secrets.ps1:89` tunnel) | same `-e` but no `age` | global | same leak | **leanest** if host trusted |
| **B: Podman secrets** `podman secret create` + `podman run --secret source=...` mount `/run/secrets/` | `podman` on host (already `vm/cloud-init/user-data.yaml.tpl:15`) | `--secret` mount, no env exfil, `podman secret ls` | per-user secret `gleiphnir-home-$USER` volume or per-run | ephemeral tmpfs | **lean+correct**, aligns with `podman` |
| **C: Per-volume bind** `/srv/sandbox/secrets/$USER/` on `DATA_DISK` `vm/guest/bin/sandbox-shell:11` | none | `-v /srv/sandbox/secrets/$USER:/run/secrets:ro,R` | per-user persistent, dev keeps | agent `/run/secrets` tmpfs empty | good for dev vs agent split |
| **D: Go age lib in 005 binary** `filosottile/age` (no bin) | none (lib in binary) | decrypt in binary then `scp` | global | needs `005` | defers `age`, keep file |
| **E: Vault/1P** | `vault` service | pull at boot `cloud-init runcmd` | — | — | bloat, no |

**Prelim lean:** **A for now (drop age)** if host is dev laptop; **B (+ C split)** for `005` binary: `gleiphnir secrets sync` creates `podman secret` per user on VM, long-running dev binds persistent `C`, AI agent microVM gets `--secret` empty. Task spikes `B`.

## Proposed change (decision task)

- **Spike:** Branch `chore/tasks-004-secrets`, keep bash scripts but implement `B`: host `vm/scripts/secrets.sh sync` → `ssh admin@VM "podman secret create gleiphnir-$USER --env-file -"` or `echo $line | podman secret create`, guest `vm/guest/bin/sandbox-shell:123-130` change `if podman secret exists; then COMMON_ARGS+=(--secret gleiphnir-$USER,type=env) else fallback -e`. Keep `vm/guest/bin/sandbox-secrets` shim for `B` or drop.
- **If accepted:** Update `config/sandbox.env:99-104` `SECRETS_ENABLED age`→`SECRETS_BACKEND=podman|file` (keep `age` optional), edit `vm/scripts/secrets.sh` (bash) `encrypt/decrypt` no-op or use `age` lib later `005`, `sync` writes secret not file, `vm/guest/bin/sandbox-shell` secret handling, `mise.toml:256-279` tasks keep same names, `docs/commands/*.md` updated. `.gitignore:20` keeps `secrets.env` ignored; delete `*.enc` ignore if dropping `age`.
- **If A only:** Delete `Test-AgeInstalled` `vm/scripts/secrets.ps1:27`, delete `SECRETS_AGE_PUBKEY` `config/sandbox.env:104` requirement, keep plain `scp`.

## Verification

```bash
mise run secrets:status            # plaintext exists?, age? (post-A: no age)
echo "FOO=bar" >> config/secrets.env
mise run secrets:sync              # A: scp /var/lib/sandbox/secrets.env ; B: podman secret create
ssh admin@192.168.100.10 "ls -l /var/lib/sandbox/secrets.env; sudo podman secret ls; sudo /usr/local/bin/sandbox-secrets list"
ssh alice@192.168.100.10 env | grep FOO   # inside podman, should show
# Firecracker ephemeral check:
ssh admin@192.168.100.10 "sudo podman run --rm --secret gleiphnir-alice ... env | grep FOO"
# secrets don't survive snapshot if using B tmpfs
```

## Rollback

Feature flag `SECRETS_BACKEND=file` in `config/sandbox.env` keeps old `vm/scripts/secrets.sh` + `vm/guest/bin/sandbox-shell:126` file path; revert `podman secret` shim.

## Checklist

- [ ] Spike A vs B, measure `age` dep removal, `podman secret` on `DATA_DISK` vs tmpfs for Firecracker
- [ ] ADR choice in task (A leanest / B correct for split volumes)
- [ ] If change: `vm/scripts/secrets.sh`, `vm/guest/bin/sandbox-shell`, `config/sandbox.env`, `mise.toml` tasks kept
- [ ] Docs `docs/commands/gleiphnir-secrets.md`, `docs/commands/fenrir-secrets.md`
- [ ] Status `done`, feeds `005` binary `podman secret` embed
