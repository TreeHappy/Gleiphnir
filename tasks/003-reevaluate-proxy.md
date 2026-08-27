---
id: 003
title: Reevaluate proxy (mitmproxy → lean tinyproxy/squid/haproxy or nftables)
status: todo
priority: medium
depends_on: [002]
estimate: "1-2d"
branch: chore/tasks-003-proxy
---

## Goal / Non-Goals

- **Goal:** Decide lean successor to `vm/guest/bin/sandbox-proxy:1-285` (`mitmdump`+Python addon enforcing `policy` egress `Domain→allowlist, CIDR→ufw`) for bash host + single binary. Must stay single-binary minimal: host binary + `qemu|podman|firecracker` only, `bash` host, tiny guest. Support long-running dev (persistent volumes) + Firecracker AI agents (ephemeral microVMs) same policy `docs/policy.md:1-62`.
- **Non-Goals:** No secrets redesign (`004`), no QEMU→Firecracker migration (`005` spike), no full `mitmproxy` removal until `sandbox-policy` parity proven.

## Current state (file:line refs)

- Guest proxy: `vm/guest/bin/sandbox-proxy:1-285` runs `mitmdump --listen-port 8080` `vm/guest/bin/sandbox-proxy:277-284` with addon `vm/guest/bin/sandbox-proxy:22-270` that (1) `load_allowlist` `vm/guest/bin/sandbox-proxy:37-79` from `/etc/sandbox/proxy-allowlist.txt`, (2) `is_denied` `vm/guest/bin/sandbox-proxy:83-97` from `/var/lib/sandbox/policy.json` `vm/guest/bin/sandbox-policy:8-10`, (3) `request()` deny wins → `403` `vm/guest/bin/sandbox-proxy:108-143`, (4) `response()` OTel spans → `http://127.0.0.1:4318/v1/traces` `vm/guest/bin/sandbox-proxy:14,167-243` + JSONL `/var/log/sandbox/proxy-*.jsonl` `vm/guest/bin/sandbox-proxy:12,245-268`, W3C `traceparent` `vm/guest/bin/sandbox-proxy:173-180`.
- Policy owns allowlist: `vm/guest/bin/sandbox-policy:165-187` `sync_proxy_allowlist()` union `preset` `vm/guest/policy-presets/balanced.txt` (60+ domains `vm/guest/policy-presets/balanced.txt:1` npm/pypi/crates/go/apt/mise/docker/github/exa.ai `docs/policy.md:35`) + `global.allow`, writes `/etc/sandbox/proxy-allowlist.txt`, `pkill -HUP mitmdump` `vm/guest/bin/sandbox-policy:186`. Containers get `http_proxy=http://$VM_IP:8080` `vm/guest/bin/sandbox-shell:134-148` (+ `_PROXY_HOST` via `ip route`).
- Cloud-init: `vm/cloud-init/user-data.yaml.tpl:29` `mitmproxy` in `packages`, guest `otlp` `vm/cloud-init/user-data.yaml.tpl:209` placeholder, `vm/guest/bin/sandbox-policy:230-234` `ufw default deny outgoing + allow 53,80,443` for non-`open`.
- Cost: `mitmproxy` heavy (Python, cert MITM `upstream_cert=false ssl-insecure` `vm/guest/bin/sandbox-proxy:280`, ~300MB layer), bloats `container/Containerfile` not but `cloud-init` VM image, slow on Firecracker 256MB microVM, duplicates OTel (guest already OTel Collector `vm/guest/lib/otelcol-config.yaml`).

## Lean evaluation

| Option | Guest deps | Binary host deps | Wildcard `*.exa.ai` | HTTP logging (OTel/JSONL) | Firecracker fit | Lean |
|---|---|---|---|---|---|---|
| **Keep mitmproxy** | `mitmproxy` python + addon `vm/guest/bin/sandbox-proxy:22` | — | yes `*.` `vm/guest/bin/sandbox-proxy:59-68` | yes spans `vm/guest/bin/sandbox-proxy:145` + JSONL | poor (heavy) | no |
| **A: tinyproxy + allowlist Filter** | `tinyproxy` (~200KB) `Filter /etc/tinyproxy/filter + FilterDefaultDeny Yes` | write `filter` file | yes (plain suffix) | access log only, no spans | excellent | **yes** |
| **B: squid + acl** | `squid` (`acl allowed dstdomain ... http_access allow`) | write `squid.conf` | yes via `acl` | `access.log` | good | yes |
| **E: haproxy (forward + SNI)** | `haproxy` ~2-3MB static (`mode http` + `mode tcp` SNI, `option http_proxy` removed ≥2.5 so custom `http-request deny`/`tcp-request content reject`) | write `/etc/haproxy/allowlist.acl` + reload `haproxy -sf` | yes via `acl allowed dstdom -i -m end .exa.ai` + `req.ssl_sni -m end .exa.ai` (parity `vm/guest/bin/sandbox-proxy:59-68` `host_matches`/`vm/guest/bin/sandbox-policy:130`), SNI avoids MITM cert | `log-format` JSON → file/syslog → OTel Collector tail (no per-request span `sandbox-proxy:145`, parity with tinyproxy) | excellent (<5MB RSS, <200ms reload via `-sf`) | **yes — lean+observable, SNI-filter avoids MITM** |
| **C: dnsmasq + nftables set** | `dnsmasq` (allowlist → ipset `nft set`) + `ufw/nft` `allow 53` | resolve domains at `allow` time | no MITM, needs re-resolve TTL | no HTTP payload | excellent | leanest, no proxy env |
| **D: no proxy, pure ufw egress** | — (only `vm/guest/bin/sandbox-policy:230-234`) | `ufw allow out to CIDR` | no (`ufw` IP only, `is_ip_or_cidr` `vm/guest/bin/sandbox-policy:156-163` branch) | no | excellent | leanest but breaks `*.` preset |

**Prelim lean:** **A (tinyproxy) vs E (haproxy) lead** for dev — `A` simplest `Filter`, `E` richer ACL/rate-limit/observability and still <5MB RSS, both beat `B` on image size. `E` SNI-filter avoids MITM cert `vm/guest/bin/sandbox-proxy:280` entirely (`mode tcp` `req.ssl_sni`). **C/D** for AI agents where HTTP logging not required. `C` avoids `http_proxy` `vm/guest/bin/sandbox-shell:142` entirely (binary sets `no_proxy`). Spike `A` vs `E` head-to-head on 256MB Firecracker microVM.

## Proposed change (decision task, not impl unless approved)

- **Spike (this task):** Branch `chore/tasks-003-proxy`, install tinyproxy **and haproxy** side-by-side in `cloud-init` or `container` for head-to-head. For `A` point `sandbox-shell:142` `http_proxy= $VM_IP:8888`, map `proxy-allowlist.txt` → `tinyproxy filter` (`sync_proxy_allowlist` `vm/guest/bin/sandbox-policy:165` emits `Filter` lines, `SIGHUP`→`kill -HUP tinyproxy`). For `E` point `sandbox-shell:138-147` `http_proxy=http://$VM_IP:8888` + `https_proxy` same, haproxy `frontend proxy_in bind :8888 mode http` `acl allowed dstdom -i -f /etc/sandbox/haproxy-allowlist.acl` `http-request deny deny_status 403 if !allowed` + `frontend sni_in bind :8889 mode tcp` `tcp-request inspect-delay 5s` `acl allowed_sni req.ssl_sni -m end -f /etc/sandbox/haproxy-allowlist.acl` `tcp-request content reject if !allowed_sni` (note `option http_proxy` removed ≥2.5 — use custom ACLs, test `503` regression per StackOverflow). `sync_proxy_allowlist` `vm/guest/bin/sandbox-policy:165` emits both `tinyproxy filter` and `/etc/haproxy/allowlist.acl` (sorted `vm/guest/bin/sandbox-policy:181`) and reloads `haproxy -f /etc/haproxy/haproxy.cfg -sf $(cat /run/haproxy.pid)` vs `pkill -HUP mitmdump:186`. Test `sandbox-policy allow network registry.npmjs.org` → `curl https://registry.npmjs.org` inside `podman run` succeeds, `curl https://evil.com` → `403`/`503` on both impls, `curl https://api.exa.ai` → `*.exa.ai` allowed `vm/guest/policy-presets/balanced.txt:70`.
- **If accepted (A/E):** Replace `vm/guest/bin/sandbox-proxy` with `sandbox-proxy-tiny` or `sandbox-proxy-haproxy` shim (keep `sandbox-proxy` name for compat), edit `vm/cloud-init/user-data.yaml.tpl:29` `mitmproxy`→`tinyproxy` or `haproxy` (guarded by `PROXY_IMPL=haproxy|tinyproxy|squid|mitmproxy` `config/sandbox.env:76` like `OBSERVABILITY_PROXY_ENABLED`), remove `sandbox-proxy:145-268` span/JSONL unless `OBSERVABILITY_PROXY_ENABLED=true` `config/sandbox.env:81` needs it (gate) — haproxy `log-format` JSON → OTel Collector tail replaces span. Update `vm/guest/bin/sandbox-policy:230` `ufw` posture unchanged, `vm/guest/bin/sandbox-shell:134-148` proxy port (8888 default `tinyproxy`/`haproxy`). Docs `docs/policy.md:10`, `docs/architecture.md:28`. Provide `haproxy.cfg` template `frontend proxy_in`+`backend out mode http` + `frontend sni_in mode tcp` + `backend out_tcp mode tcp`.
- **If C:** Drop proxy, edit `vm/guest/bin/sandbox-shell:134-148` to not set `http_proxy`, implement `nft` set resolver in `sandbox-policy allow` (resolve `pattern`→IP via `getent`, `ufw allow out to $ip`).
- **Host bash/binary:** `vm/scripts/manage-policy.sh` (bash port of `vm/scripts/manage-policy.ps1`) unchanged; single binary `005` embeds `proxy-allowlist.txt` template **and `haproxy.cfg`/`allowlist.acl` template** via `go:embed`.

## Verification

```bash
# after spike, either tinyproxy / haproxy or no-proxy
ssh admin@192.168.100.10 "sudo sandbox-policy init balanced && sudo sandbox-policy ls --wide"
ssh admin@192.168.100.10 "sudo sandbox-proxy --help 2>&1 | head"  # if kept shim
ssh admin@192.168.100.10 "haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl is-active haproxy; cat /etc/sandbox/haproxy-allowlist.acl | head"
ssh admin@192.168.100.10 "cat /var/log/sandbox/haproxy*.log | head"  # haproxy log-format JSON
ssh alice@192.168.100.10  # lands in podman sandbox-shell
# inside container (podman):
curl -v https://registry.npmjs.org  # allowed via preset vm/guest/policy-presets/balanced.txt:70
curl -v https://evil.example 2>&1 | grep -i "403\|503\|denied\|blocked"  # denied (haproxy 403, tinyproxy 503)
curl -v https://api.exa.ai  # allowed *.exa.ai vm/guest/policy-presets/balanced.txt:115 via -m end / req.ssl_sni
# policy check:
ssh admin@192.168.100.10 "sudo sandbox-policy check network api.github.com:443"  # Allowed
# (optional OTel)
[[ $OBSERVABILITY_PROXY_ENABLED == true ]] && curl http://127.0.0.1:4318/v1/traces -d '{}' -v
# measure lean:
du -sh /usr/sbin/haproxy /usr/sbin/tinyproxy /usr/sbin/squid 2>/dev/null; ps -o pid,rss,cmd -C haproxy -C tinyproxy -C mitmdump
```

## Rollback

Keep `mitmproxy` install behind `if [[ $PROXY_IMPL == mitmproxy ]]` `config/sandbox.env:76` until spike merges; revert branch.

## Checklist

- [ ] Spike tinyproxy **and haproxy** (and optionally dnsmasq) on dev VM + Firecracker 256MB microVM — head-to-head A vs E
- [ ] Measure: guest image size, boot time, `mitmdump` vs `tinyproxy` vs `haproxy` RAM/RSS, reload latency `haproxy -sf` vs `SIGHUP`
- [ ] Decision ADR in task (A/B/C/D/**E**) with wildcard/policy parity `vm/guest/bin/sandbox-proxy:59` + `vm/guest/bin/sandbox-policy:130` `domain_matches` proof (`*.exa.ai` via `-m end` + `req.ssl_sni -m end`)
- [ ] If change: edit `user-data.yaml.tpl:29`, `sandbox-policy:165` `sync_proxy_allowlist` (emit both `filter` + `haproxy-allowlist.acl`), `sandbox-shell:134` proxy env, add `haproxy.cfg` template, `config/sandbox.env:76` `PROXY_IMPL`
- [ ] Docs `docs/policy.md:10`, `docs/architecture.md:12-28` updated (haproxy/tinyproxy selectable)
- [ ] Status `done`, feeds `005` binary `proxy-allowlist` + `haproxy.cfg` embed
