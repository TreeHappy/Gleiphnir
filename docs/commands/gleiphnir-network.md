# `gleiphnir network` — Host networking (bridge/TAP)

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:16` `network` (host, `mise run network:*`)
**Mise tasks:** `network:up|down|status` (`mise.toml:48`)

## Synopsis

```
gleiphnir network up          # create bridge + TAP (Linux, requires sudo)
gleiphnir network down        # remove bridge + TAP
gleiphnir network status      # show bridge/TAP/iptables status
```

| Sub | → `mise` | Description |
|---|---|---|
| `up` | `network:up` | `vm/scripts/network-up.ps1` — private bridge `br-gleiphnir` 192.168.100.0/24, TAP `tap-gleiphnir`, DNAT `:2233→VM:22` |
| `down` | `network:down` | `vm/scripts/network-down.ps1` |
| `status` | `network:status` | `vm/scripts/network-status.ps1` |

## Notes

- `bridge` mode preserves source IPs so `ufw` inside VM can filter.
- `PHYS_IF=` enslaves a real NIC for true LAN bridge.

## Execution

`run: "[mise, run, network:up]"` via shim.

## Examples

```bash
gleiphnir network up
gleiphnir network status
gleiphnir network down
```

## See Also

- `docs/commands/gleiphnir-vm.md`
- `vm/scripts/network-up.ps1:1`, `vm/scripts/lib.ps1:49` `BRIDGE_NAME`/`TAP_NAME`
- `docs/architecture.md#networking-modes`
