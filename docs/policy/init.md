# `gleiphnir policy init` — initialize preset

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:110` `policy init` (host, `vm/scripts/manage-policy.ps1` → `vm/guest/bin/sandbox-policy:190` `cmd_init`)

## Synopsis

```
gleiphnir policy init [balanced|open|locked|allow-all|deny-all]
gle policy init balanced   # or: mise run policy:init -- balanced
```

If no `preset` given and TTY present, prompts:

```
Initialize the global network policy for your sandboxes:
  1. Open        — All outbound traffic allowed (allow **)
  2. Balanced   — Default deny, common dev sites allowed (npm, pypi, github, exa.ai, …)
  3. Locked Down — All outbound blocked
```

Non-interactive (CI) → defaults to `balanced` (`config/sandbox.env:POLICY_PRESET=balanced`). VM cloud-init runs `sandbox-policy init balanced` on first boot (`vm/cloud-init/user-data.yaml.tpl:230`).

## Description

Writes `preset` to `/var/lib/sandbox/policy.json` and syncs `/etc/sandbox/proxy-allowlist.txt` + `ufw default`:
- `open` → `**` in allowlist + `ufw default allow outgoing`
- `balanced/locked` → curated allowlist (or empty) + `ufw default deny outgoing` (+ `allow out 53,80,443` for DNS)

## Examples

```bash
gleiphnir policy init balanced
gle policy init open
mise run policy:init -- locked
```

## See Also

`docs/policy.md` (global), `docs/policy/preset.md` (alias), `docs/policy/ls.md`
