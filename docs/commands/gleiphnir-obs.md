# `gleiphnir obs` — observability (Grafana LGTM)

**Spec:** `vm/files/carapace/specs/gleiphnir.yaml:308` `obs` alias `observability` (host, `mise run obs:*`)
**Mise tasks:** `obs:start|stop|status|open|deploy|clean` (`mise.toml:225`)

## Synopsis

```
gleiphnir obs start       # start LGTM container on host + deploy agents to VM
gleiphnir obs stop        # stop LGTM
gleiphnir obs status      # show status
gleiphnir obs open        # open Grafana dashboard
gleiphnir obs deploy      # deploy agents to running VM (after obs:start)
gleiphnir obs clean       # remove LGTM container and data volume
```

| Sub | → `mise` | Description |
|---|---|---|
| `start` | `obs:start` | `vm/scripts/observability.ps1 start` + `deploy-observability.ps1` if `OBSERVABILITY_ENABLED=true` |
| `stop` | `obs:stop` |  |
| `status` | `obs:status` |  |
| `open` | `obs:open` | Grafana `http://127.0.0.1:3000` |
| `deploy` | `obs:deploy` |  |
| `clean` | `obs:clean` |  |

## Execution

`run: "[mise, run, obs:start]"` etc.

## Examples

```bash
gleiphnir obs start
gleiphnir obs status
gleiphnir obs open
gleiphnir obs clean
```

## See Also

- `docs/observability.md`, `vm/scripts/observability.ps1:1`, `vm/scripts/deploy-observability.ps1:1`
- `config/sandbox.env:70` `OBSERVABILITY_ENABLED`, `OBSERVABILITY_GRAFANA_PORT`
