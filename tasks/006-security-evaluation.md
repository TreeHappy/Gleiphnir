---
id: 006
title: "Security evaluation vs Vibe Check — Secrets Management for Agentic Systems (GQYI9DyX_pI) + hardening roadmap"
status: done
priority: high
depends_on: [001, 002, 003, 004, 005]
estimate: "planning + 1d spike"
branch: chore/tasks-006-security-evaluation
---

## Goal / Non-Goals

- **Goal:** Evaluate Gleiphnir *today* (commit `c5dd5cb` / branch `main`) against the threat model in `https://www.youtube.com/watch?v=GQYI9DyX_pI` — Temporal Vibe Check: *Secrets Management for Agentic Systems* (Cecil Phillip @Temporal + Jake Hulberg @Infisical, streamed 2026-08-26 11am-12pm PST, `oembed` `Temporal • 148 views • Gestreamd 11u geleden`, description extracted via `curl .../watch?v=GQYI9DyX_pI | grep attributedDescription`) — and translate what "people like here" (hardened-sandbox / platform / AI-agent-infra crowd that follows Docker Sandbox, Quicksand, `less-lethal`, `agent-sandbox`, Vibe Check) would think. Capture in `tasks/` so `003` (proxy), `004` (secrets), `005` (single binary) have a security-grounded ADR input. No code in this task — doc + verification checklist only.
- **Non-Goals:** No implementation (`003`/`004` spikes do it), no transcript dump (YouTube `LOGIN_REQUIRED` bot gate, `captionTracks` absent; fallback `oembed`/`noembed` + `infisical.com/blog/agent-proxy` + `Infisical/agent-vault` MIT), no Windows re-add (`001` stays `done`).

## Video — what it actually is

| Field | Value | How verified |
|---|---|---|
| Title | `Vibe Check: Secrets Management for Agentic Systems` | `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=GQYI9DyX_pI&format=json` → `title`, also `noembed.com/embed?url=...`, HTML `videoDetails.title` |
| Channel | `Temporal @Temporalio` | `oembed.author_name`, `author_url https://www.youtube.com/@Temporalio` |
| Guests | `Cecil Phillip` (Temporal, Sr Staff Dev Advocate) + `Jake Hulberg` (Infisical, Dev Advocate) | `daily.dev/posts/vibe-check-secrets-management-for-agentic-systems-txdopq1ex`, LinkedIn `cecil-phillip` `7493723581110046721`, `jake-hulberg-914964193` `7494307105089183744` |
| When | Scheduled `Aug 26 2026 11am-12pm PST` / livestreamed `~2026-08-27 00:00 UTC` (`11 uur geleden` + `is_viewed_live True`) | description `Date/Time: August 26, 11am-12pm PST`, HTML `relativeDateText`, daily.dev `2026-08-05T16:57:41Z` announcement |
| Views | 148 at crawl | HTML `videoDetails.subtitle` |
| Duration | ~60 min | schedule + sibling Vibe Checks `56:08`/`56:41` |
| Core line | *"Every AI agent that calls a tool/API needs credentials — most demos skip the security surface. Agents shouldn't see your secrets."* | `attributedDescription.content` via `curl -sL -A Mozilla/5.0 https://www.youtube.com/watch?v=GQYI9DyX_pI | grep attributedDescription` |
| 5 topics | Live demo Infisical Agent Proxy, What Infisical is & why it exists, Why agents need security, Real-world use cases, How to actually secure agents | same description + `infisical.com/blog/agent-proxy` |

**Mechanism demoed:** dummy `ANTHROPIC_API_KEY=__anthropic_api_key__` (401 if used raw) in agent env, `HTTPS_PROXY` → Infisical Agent Proxy (MITM with locally-trusted CA, scans `header/path/query/body`, swaps `__placeholder__` → real secret fetched from Infisical vault, re-TLS upstream). Agent does real work (read GitHub issues → PR) while attacker `curl attacker.com` via prompt-injected `env` only leaks dummy. Infisical states: proxy is *new infra primitive alongside sandboxes* (like `sbx`), interface-agnostic (HTTPS layer covers CLI/SDK/MCP) vs MCP-gateway-only; recommend separate host but private-net-close; 30+ `Proxied Service` presets, `Secret Substitution` / `Header Rewrite`, machine identities (`Read Value + Describe Secret` for proxy vs `Proxy` only for agent), audit/log per request, dynamic short-lived leases (`Manage Leases`). Predecessor `Infisical/agent-vault` (transparent MITM, MIT, 2k stars May 2026, `HTTPS_PROXY=<token>:vault@addr:14321/14322`). SigV4/HMAC signing still roadmap (agent can't sign without secret).

**Why it matters here:** Gleiphnir = `README.md:3` *open-source alternative to Docker Sandbox — QEMU + Ubuntu 26.04 + ufw + Podman + mise + pwsh*, ephemeral read-only container `vm/guest/bin/sandbox-shell:1` (`--read-only --cap-drop ALL --security-opt no-new-privileges`) on `QEMU` VM `vm/scripts/start-vm.ps1:1` (`-enable-kvm -cpu host` else `tcg`, `TAP tap-gleiphnir → br-gleiphnir 192.168.100.0/24` + DNAT `:2233→192.168.100.10:22` `vm/scripts/network-up.ps1:92-101`). Guest egress already `mitmproxy :8080` (`vm/guest/bin/sandbox-proxy:1-285`) + `ufw` `vm/guest/bin/sandbox-policy:1` like `sbx policy`. Video fills the missing credential layer.

## Current state — threat model & posture (file:line refs)

- **Entry / isolation:** `vm/scripts/start-vm.ps1:95-109` `qemu-system-x86_64 -drive file=SYSTEM_DISK,if=virtio -drive file=DATA_DISK,if=virtio -drive file=SEED_ISO,if=virtio,format=raw,readonly=on -display none -daemonize -serial file:CONSOLE_LOG -monitor unix:MONITOR_SOCK,server,nowait` (`vm/scripts/lib.ps1:112-116` derived `PID_FILE/CONSOLE_LOG/MAC_FILE/MONITOR_SOCK`). `vm/cloud-init/user-data.yaml.tpl:14-30` `podman/ufw/uidmap/slirp4netns/fuse-overlayfs/openssh-server/qemu-guest-agent/mitmproxy`. `container/Containerfile:1-51` `ubuntu:26.04` + `mise` binary `curl https://mise.run | sh` `7-27` + `useradd dev:1000 -s /usr/local/bin/sandbox-pwsh` `30-34`, `rm -f /usr/bin/sudo /usr/bin/su` `21`.
- **Container (the sandbox):** `vm/guest/bin/sandbox-shell:96-121` `COMMON_ARGS=(--rm -it --read-only --tmpfs /tmp:rw,size=512m,1777 --tmpfs /run:rw,size=64m,755 --cap-drop ALL --security-opt no-new-privileges --pids-limit 512 --memory 2g --cpus 2 -v gleiphnir-home-$USER:/home/dev:rw,U -v sandbox-mise:/opt/mise-shared:rw,U -v /srv/sandbox/$USER:/work:rw ...)`, `--userns keep-id` `152-158` or `sudo podman` fallback. `container/entrypoint.sh:1-58` `mise trust --all` + `mise install --yes` + `mist run dotfiles` + shims `MISE_DATA_DIR/shims:$PATH`, then `exec /usr/local/bin/sandbox-pwsh` (fallback `bash`). Share volumes: `gleiphnir-home-*` `sandbox-mise` `DATA_DISK /srv/sandbox` `config/sandbox.env:20` `20G`.
- **Policy / firewall:** `vm/guest/bin/sandbox-policy:8-10` `POLICY_FILE=/var/lib/sandbox/policy.json` `PROXY_ALLOWLIST=/etc/sandbox/proxy-allowlist.txt` `PRESET_DIR=/etc/sandbox/policy-presets`. Presets `vm/guest/policy-presets/balanced.txt:1-71` 71 lines (github `4-16`, npm `17-22`, pypi `23-26`, crates `27-30`, go `31-35`, nuget `36-38`, maven `39-42`, rubygems `43-44`, ubuntu `46-50`, mise `51-54`, docker `55-61`, vscode `62-64`, openai/anthropic `66-68`, exa.ai `69-71`), mirrors `docs/policy.md:35`. `vm/guest/bin/sandbox-policy:165-187` `sync_proxy_allowlist()` sorts union preset+`global.allow` → `$PROXY_ALLOWLIST`, `pkill -HUP mitmdump`. `vm/guest/bin/sandbox-policy:130-154` `domain_matches()` (`**`/`*.host`/`*.host:port` permissive). `vm/guest/bin/sandbox-policy:190-237` `cmd_init()` sets `ufw default deny outgoing` + `allow out 53,80,443` unless `open`. `vm/guest/bin/sandbox-proxy:37-80` `load_allowlist()`, `83-97` `is_denied()` from `policy.json`, `108-143` `request()` deny-wins 403 + `proxy-*.jsonl` `egress_denied`. `145-268` `response()` OTel span to `127.0.0.1:4318/v1/traces` + `traceparent` `173-180` + JSONL `245-268`. Injected `http_proxy=http://$VM_IP:8080` `vm/guest/bin/sandbox-shell:134-148` (`_PROXY_HOST via ip route get 1.1.1.1`).
- **Ingress:** `vm/cloud-init/user-data.yaml.tpl:261-265` `ufw default deny incoming; allow from any to any port 22` (bootstrap). `vm/guest/bin/sandbox-firewall:251-293` `enforce` deletes `allow from any to any port 22`. `docs/architecture.md:13` documents. `vm/guest/bin/sandbox-firewall:1-120` `allow/deny/remove/list` via `ufw allow from $IP to any port 22`.
- **Secrets (today):** `config/sandbox.env:99-104` `SECRETS_ENABLED=false` `SECRETS_AGE_PUBKEY=`. `vm/scripts/secrets.ps1:1-129` `encrypt` `age -r $pubKey -o $SECRETS_ENC` `47`, `decrypt` `age -d -i ~/.ssh/gleiphnir_secrets_key` `59,65`, `sync` `scp $SECRETS_PLAIN admin@VM:/var/lib/sandbox/secrets.env` `constant` `85` + `chmod 600` `93` + `touch secrets-enabled`. Guest `vm/guest/bin/sandbox-secrets:1-131` `list/set/remove/export/rotate` on `SECRETS_FILE=/var/lib/sandbox/secrets.env`, `vm/guest/bin/sandbox-shell:123-130` injects `while read line; [[ $line == #* ]] continue; COMMON_ARGS+=(-e "$line")`. `mise.toml:256-279` `secrets:init|encrypt|decrypt|sync|list|status`. `.gitignore:20-21` `secrets.env` + `secrets.env.enc`. `docs/observability.md:187-225` flow.
- **Observability:** `vm/guest/bin/sandbox-session-logger:1-47` `script -qfec` PTY, `vm/guest/bin/sandbox-journal:1-105` JSONL query, `otelcol` `vm/guest/lib/otelcol-config.yaml`, `node-exporter :9100`, LGTM `grafana/otel-lgtm:latest` `config/sandbox.env:68-78` `3000/4317/9090`. `container/files/mise.toml:6-32` tools + `dotfiles` task.
- **Planned lean:** `001 done` (Linux-only KVM/bridge, `unix:` monitor, no `whpx`/`oscdimg`), `002 todo` `pwsh→bash` `set -euo pipefail` + `shellcheck`, `003 todo` proxy spikes `tinyproxy Filter` vs `squid acl` vs `haproxy -m end + req.ssl_sni -m end` vs `dnsmasq+nft` vs `ufw-only` (`mitmproxy` ~300MB layer → 200KB/2-3MB), `004 todo` secrets spikes `A drop age trust host` vs `B podman secret --secret` vs `C per-volume bind` vs `D go age lib` (`podman secret` = ephemeral `tmpfs /run/secrets`), `005 planning` `Go static 12-18MB` `go:embed` `Launcher {QEMU|Firecracker}` two profiles (dev `QEMU` 4G persistent `DATA_DISK` vs AI `Firecracker` 128-512M ephemeral snapshot `virtiofs/vsock`).

## What "people like here" actually think (synthesis)

Context: `tasks/` audience + siblings `docker.com/blog/comparing-sandboxing-approaches-ai-agents` (MicroVM per agent, `sbx`), `microsoft/quicksand` (`QEMU` `NetworkMode.FULL`, snapshots), `helyovw2010/exec-sandbox` (9-layer MicroVM `SNI filter`, hardened kernel), `eleostech/less-lethal` (`mitmproxy allowlist` `filter.py` + `418`), `mattbucci/agent-sandbox` (`Firecracker` `nftables+Squid ssl_bump splice`), `blog.trailofbits.com/2026/08/26 vms-wont-contain-cyber-capable-agents` (GPT-5.6-Cyber escaped `QEMU/KVM` Debian/Zen3 three times: `Januscape CVE-2026-53359`, `libslirp CVE-2026-9539 + IHL overflow`, then 3 0-days `VAPIC SMRAM`, `KVM paging64_invlpg`, `libslirp ICMP`).

1.  **“This is the missing half”** — Gleiphnir nails *compute + network* (VM kernel, `--read-only`, `ufw deny + mitmproxy allowlist`). Infisical nails *credential* isolation. They are complements. Expect immediate request: either Document `infisical agent-proxy` sidecar (run proxy on host private net `192.168.100.1:8081`, point `http_proxy` there, env `GITHUB_TOKEN=__ghp_placeholder__`, CA via `infisical agent-proxy connect`) as doc-only, or — preferred by OSS purists (`README.md:3` “only open-source components, no Docker Sandbox proprietary”) clone the pattern natively in `vm/guest/bin/sandbox-proxy` (transparent MITM `MIT`-licensed `agent-vault` proof). Label: necessary not sufficient.

2.  **OSS purism vs. Infisical commercial** — `agent-vault` OSS self-hostable → community says Gleiphnir could implement `Secret Substitution` itself (load `secrets.json` in Python addon, `flow.request.headers["Authorization"] = flow.request.headers["Authorization"].replace("__GITHUB_PAT__", real)` etc.) without vault centralization. Pragmatists counter: Infisical rotation/dynamic leases/30 presets/RBAC/audit/free tier is non-trivial. Suggest hedge: keep `mitmproxy` shim name (`sandbox-proxy`) compat while spiking `haproxy` replacement (`003`).

3.  **VM-escape humbles** — Trail-of-Bits resonates hard. Gleiphnir = escaped stack (`QEMU+KVM+Debian`). Audience notes mitigations: tap bridge avoids `libslirp` SLIRP NAT vector (Gleiphnir uses `tap`, not `hostfwd`/`usernet` — good), `display none`, minimal `qemu -cpu`, but `KVM` still. Expect `Firecracker` / `Kata` / `gVisor` lobby vs “Gleiphnir aims at dev ergonomics + `sandbox-mise` cache, not ultra-hardened prod — pin `resolute` `archive.ubuntu.com` `55`, rapid `systemd` `sandbox-container-build.service` rebuild, least-privilege + monitoring”. Add assumption: treat escaped agent as APT — add time-limit, pristine env per run, LGTM alerts.

4.  **Policy parity hype** — Gleiphnir `balanced.txt` 60+ already mirrors `sbx` + `exa.ai` `69-71`. Video per-host brokering `deny wins` = `sandbox-policy:313` `is_denied` before `is_allowed`, `policy check network` `vm/guest/bin/sandbox-policy:401-476` + `vm/scripts/manage-policy.ps1` parity. `mitmproxy 8080 + http_proxy + JSONL→OTel` architecturally identical to `less-lethal`/`agent-proxy`. Debate goal: merge `SNI` filtering (`haproxy` `req.ssl_sni -m end`) to catch agents who `unset http_proxy`.

5.  **Temporal durability** — Other Vibe Checks (`Agents don't need your password… Auth0`, `There's no agent without the harness` — durable workflows, human approval waiting hours) map to Gleiphnir ephemeral `--rm` container pain: long agents need history outside VM. Community wants `Temporal` durable execution + Gleiphnir network/secret primitives as the harness.

6.  **Sec review stance: “needed not sufficient”** — Video diagnoses `prompt injection → exfiltration`, proxy fixes cred theft, but not command deny, `fence` style `tool` ACLs, SSH `AllowTcpForwarding no` `vm/cloud-init/user-data.yaml.tpl:218-219`, `SBOM` `sbom:container|tools|vm|all` `mise.toml:183-198` + `vm/guest/bin/sandbox-sbom`, `cgroups` (`--pids-limit 512 --memory 2g --cpus 2`). Recipe they’ll push: `QEMU VM + Podman --read-only + mitmproxy placeholder swap + dynamic 2m-TTL tokens + policy init locked` + per-sandbox proxy port isolation.

## Evaluation — scores

| Dimension | Score | Rationale |
|---|---|---|
| Compute isolation | **8/10** | Strong (KVM VM + `--read-only` `--cap-drop ALL`) — good default. Gap: not MicroVM-hardened (`Firecracker`/`Kata`) until `005`. |
| Network isolation | **7/10** | `bridge+TAP+DNAT` preserves IPs, `ufw deny incoming`, `balanced` 60+ + `deny wins` via `mitmproxy`. Gap: proxy-bypass open via `ufw allow out 80,443` any host + `http_proxy` opt-in; no transparent `SNI`/`nft` until `003-E`. |
| Credential isolation | **3/10** | `secrets.env` global file → `-e` env → LLM sees real `GITHUB_PAT`/`OPENAI_API_KEY`; `age` host-only, no rotation/RBAC/audit/per-sandbox. Exactly the video anti-pattern. Best win if fixed. |
| Ingress | **6/10** | `ufw allow any:22` bootstrap `+ enforce` flow documented, but default still world-open until `enforce`; `sandbox-firewall:83` `SSH_CONNECTION` carve-out good. |
| Supply chain | **7/10** | `Containerfile:8-21` minimal `apt` + `mise` shared warmup `build-container.sh:14-36` + `SBOM` via `syft`. Gap: no `mise` sig verification, `curl https://mise.run | sh` (no hash), `mitmproxy ssl-insecure` `vm/guest/bin/sandbox-proxy:281`. |
| Observability / audit | **8/10** | Strong: `sandbox-journal`/`session-logger`/`proxy` JSONL + OTel `traceparent` + LGTM `3000/4317/9090` + `audit.jsonl` user add/remove `vm/guest/bin/sandbox-user:123-127`; well-scoped PID 512/mem 2g. Gap: `chmod 1777 /var/log/sandbox` `user-data.yaml.tpl:251` world-writable, `StrictHostKeyChecking=no` `vm/scripts/lib.ps1:183-186` secrets MITM risk, long `grep -c` history leak via `sandbox-journal:69`. |
| UX / dev-ergonomics | **9/10** | Best-in-class vs siblings: `mise run up` `HOST_SSH_FORWARD_PORT 2233` `fenrir tools volumes→gdu / browse→yazi` `carapace` nested, `sandbox-mise` shared downloads, `ofi-shell` → `pwsh`. Purists like it. |

Overall: Gleiphnir is ahead on *network+compute* vs most OSS sandwiches, behind on *credential* layer that video argues is now table stakes. Fixing credential brokerage (003/004) + fail-closed egress (003-E) puts it ahead of Docker `sbx` for OSS self-hosters.

## Actionable changes (map to planned tasks — decision, not code)

*   **Immediate doc (this task):** ship this file; add `docs/policy.md:10` footnote linking video + `infisical.com/blog/agent-proxy`; keep `003` `004` spikes unblocked.
*   **Short-term doc-only (before 003 merges):** Example `INFISICAL_AGENT_PROXY` sidecar: `infisical agent-proxy run --port 8081` on `BRIDGE_ADDR 192.168.100.1`, set `sandbox-shell:138-147` `https_proxy=http://192.168.100.1:8081`, container envs `GITHUB_TOKEN=__ghp_placeholder__` `ANTHROPIC_API_KEY=__anthropic_key__`, CA `~/.infisical/agent-ca`. No code — proves `HTTPS_PROXY` contract works with existing `sandbox-shell`.
*   **003 (proxy spike):** `E haproxy` recommended as lean successor (2-3MB static, `<5MB RSS`, `<200ms haproxy -sf` reload, `log-format json` → OTel tail vs per-span export) — `haproxy.cfg` `frontend proxy_in bind :8888 mode http acl allowed dstdom -i -f /etc/sandbox/haproxy-allowlist.acl http-request deny deny_status 403 if !allowed` + `frontend sni_in bind :8889 mode tcp tcp-request inspect-delay 5s acl allowed_sni req.ssl_sni -m end -f ... tcp-request content reject if !allowed_sni` (proof `*.exa.ai` via `-m end` parity `sandbox-proxy:59-68` + `sandbox-policy:130`). Keep `tinyproxy` as simpler fallback `A`. Either beats `B squid` on host deps. `mitmproxy` stays gated `PROXY_IMPL=mitmproxy` `config/sandbox.env:76` until ADR. Implement `sync_proxy_allowlist()` emit both `tinyproxy filter` and `haproxy acl` (sorted, `sort -u`). Remove `mitmdump ssl-insecure` cert MITM when `E` chosen — SNI filter avoids decrypting HTTPS at all.
*   **004 (secrets spike):** Recommend **B podman secret** `podman secret create gleiphnir-$USER --env-file -` + `podman run --secret gleiphnir-$USER,type=env` → `/run/secrets` `tmpfs` (not env) — achieves video dummy-token contract locally: container sees `GITHUB_TOKEN=__gh__` but proxy (or sidecar) injects real on egress. Details: `vm/scripts/secrets.sh sync` creates per-user secret, `vm/guest/bin/sandbox-shell:123-130` prefers `if podman secret exists gleiphnir-$USER; then COMMON_ARGS+=(--secret gleiphnir-$USER,type=env)` else legacy `-e`; retains per-sandbox scoping needed for multi-tenant. Flag `SECRETS_BACKEND=podman|file` `config/sandbox.env:99-104` revert path. `A drop age` (plaintext `0600 + scp` if host trusted) is leanest interim; `D go age lib` deferred to `005`. Either fixes global `/var/lib/sandbox/secrets.env` snapshot leak (`DATA_DISK` `vm/guest/bin/sandbox-shell:11`) — with `B`, `Firecracker` ephemeral snapshot has no `secrets.env` disk; token lease per session.
*   **006 follow → 005 (single binary):** Binary `go:embed` assets must include `haproxy.cfg` + `allowlist.acl` template and `podman secret` flow (see `005.md:44` `go:embed vm/cloud-init/... vm/guest/bin/* policy-presets/balanced.txt container/*`). Use native `go-iso9660` to finally drop `build_seed_iso.py pycdlib` dep only after template `__TOKEN__` render (`template_userdata.py:17-45` → `text/template`) proven equal.
*   **Hardenings independent of 003/004 (fast wins):** `lib.sh` (bash port) change `Get-SshCommonArgs` `StrictHostKeyChecking=no` `vm/scripts/lib.ps1:183-186` → `StrictHostKeyChecking=accept-new + UpdateHostKeys=yes` and pin host key in `known_hosts`; add `mise run fw:enforce` prompt into `mise.toml:287-300` `up` (or at least warn if bootstrap `allow any:22` still present `sandbox-firewall:289-292`); tighten `/var/log/sandbox` perms `UserData 251` from `1777` → `1770` (`root:sandbox`) and chown collector `filelog`; set `container/Containerfile:36` `ENV PYTHONDONTWRITEBYTECODE=1` etc.
*   **Policy UX:** Keep `deny wins`, add `policy preset diff` (`sandbox-policy:495-503` TODO) and `policy dump` mirror of `sbx` (`vm/scripts/dump-docker-preset.ps1`), per-sandbox proxy port isolation (`--sandbox alice` already `sandbox-policy:313` but proxy binds single `8080`; future per-sandbox `8080+$uid`). Mirror Infisical dynamic leases: document TTL 5m example `sandbox-secrets rotate GITHUB_TOKEN --ttl 300`.

## Verification (proof this eval is actionable)

```bash
# video identity still resolves
curl -s "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=GQYI9DyX_pI&format=json" | jq .title
# rg gates after 001+future 002+003+004
rg -n "IsWin|whpx|oscdimg" vm/scripts/ config/ mise.toml                # →0 post-001
rg -n "StrictHostKeyChecking=no" vm/scripts/lib.sh                    # →0 after 006 hardening
# current smoke baseline (before fixes)
mise run deps
mise run up && mise run vm:info && mise run smoke
ssh -p 2233 admin@127.0.0.1 "sudo sandbox-policy ls --wide | head -60"
ssh -p 2233 admin@127.0.0.1 "sudo sandbox-policy check network api.github.com:443; sudo sandbox-policy check network https://evil.com:443; echo exit:$?"
# inside container — egress allowlist (proxy path)
ssh alice@192.168.100.10
curl -v https://registry.npmjs.org 2>&1 | grep -E "200|403"
curl -v https://evil.example 2>&1 | grep -E "403|503|Blocked"
curl -v https://api.exa.ai 2>&1 | grep 200   # *.exa.ai via balanced.txt:69-71
# after 003-E — bypass must fail even without proxy env
# (run inside container after unset)
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
curl -v https://registry.npmjs.org 2>&1 | grep -E "denied|Blocked|timeout" || echo "FAIL: bypass succeeded"
# secrets — before fix shows real in env (the hole); after 004-B shows dummy only
ssh alice@192.168.100.10 'env | grep -E "GITHUB_TOKEN|OPENAI|ANTHROPIC"'
# should be __placeholder__ after B, real only in proxy / /run/secrets
ssh admin@192.168.100.10 "sudo podman secret ls; ls -l /var/lib/sandbox/secrets.env /run/secrets 2>&1 | head"
# observability still ships
mise run obs:status 2>&1 | head
```

## Rollback

Feature branch `chore/tasks-006-security-evaluation` — doc only. Merge to `main` immediately; no rollback needed. Technical follow-ups revert per-branch: `003` keeps `PROXY_IMPL=mitmproxy` fallback until ADR lands; `004` keeps `SECRETS_BACKEND=file` legacy path (`sandbox-shell:123-130` `-e` branch). No guest `pwsh` or VM image break.

## Checklist

- [x] Doc written in `tasks/` (this file) with `file:line` refs, video identity proof, community landscape, scores
- [ ] Spike `infisical agent-proxy` sidecar doc example (defer to `003` branch)
- [ ] `003` ADR: `haproxy` `E` vs `tinyproxy` `A` — measure RSS/boot/image size, `haproxy -sf` reload, `sandbox-policy` parity `*.exa.ai` via `-m end` + `req.ssl_sni`
- [ ] `004` ADR: `podman secret` `B` vs `drop age` `A` — per-user `gleiphnir-$USER` + ephemeral Firecracker `tmpfs`
- [ ] Fast wins: `StrictHostKeyChecking=accept-new`, `1777→1770`, `fw:enforce` prompt in `up`
- [ ] `mise run deps/up/smoke` green on `main` post-doc (no code change)
- [ ] Status `done` in front-matter (this file) — feeds `005` ADR
- [ ] Future: delete `tasks/006` only when `003+004` ADRs merged into `005`

## References (abridged, verified via `read` in this repo + `websearch`/`webfetch` externally)

- Gleiphnir sources cited above: `README.md:3`, `docs/architecture.md:1-140`, `docs/policy.md:1-62`, `docs/observability.md:1-421`, `vm/guest/bin/sandbox-shell:1-176`, `vm/guest/bin/sandbox-policy:1-542`, `vm/guest/bin/sandbox-proxy:1-285`, `vm/guest/bin/sandbox-secrets:1-131`, `vm/guest/bin/sandbox-user:1-201`, `vm/guest/bin/sandbox-firewall:1-333`, `vm/cloud-init/user-data.yaml.tpl:1-287`, `container/Containerfile:1-51`, `container/entrypoint.sh:1-58`, `container/files/mise.toml:1-113`, `vm/scripts/lib.ps1:1-256`, `vm/scripts/network-up.ps1:1-125`, `vm/scripts/start-vm.ps1:1-144`, `config/sandbox.env:1-104`, `mise.toml:1-311`
- Video + Infisical: `infisical.com/blog/agent-proxy`, `github.com/Infisical/agent-vault`, Temporal Vibe Check hosts via `daily.dev` + LinkedIn
- Landscape: `docker.com/blog/comparing-sandboxing-approaches-ai-agents`, `docker.com/blog/running-ai-agents-in-github-actions-with-docker-sandboxes`, `microsoft/quicksand`, `helyovw2010/exec-sandbox`, `eleostech/less-lethal`, `mattbucci/agent-sandbox`, `blog.trailofbits.com/2026/08/26 vms-wont-contain-cyber-capable-agents`, `rywalker.com/research/local-agent-sandboxes`

