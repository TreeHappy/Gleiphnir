#!/usr/bin/env bash
set -e

# sandbox-entrypoint.sh — runs inside the podman container as user `dev`
# Bootstraps mise against the SHARED tool volume, links dotfiles, then execs
# the requested command (default: pwsh via the sandbox-pwsh launcher).

export HOME=/home/dev

# Shared mise volumes (mounted by sandbox-shell):
export MISE_DATA_DIR="${MISE_DATA_DIR:-/opt/mise-shared/data}"
export MISE_STATE_DIR="${MISE_STATE_DIR:-/opt/mise-shared/state}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-/opt/mise-shared/cache}"
export MISE_CONFIG_DIR="${MISE_CONFIG_DIR:-/work/.mise/config}"

mkdir -p "$MISE_DATA_DIR" "$MISE_CACHE_DIR" "$MISE_STATE_DIR" "$MISE_CONFIG_DIR" 2>/dev/null || true

# Point mise at the global manifest if the workspace doesn't have its own.
if [ ! -f "/work/mise.toml" ] && [ ! -f "/work/.mise.toml" ] && [ ! -f "/work/.config/mise/config.toml" ] && [ ! -f "$MISE_CONFIG_DIR/config.toml" ]; then
  if [ -f /etc/sandbox/mise.toml ]; then
    export MISE_GLOBAL_CONFIG_FILE=/etc/sandbox/mise.toml
  fi
fi

# Bootstrap tools (lazy, idempotent). Ignore failures so the shell still opens offline.
if command -v mise >/dev/null 2>&1; then
  # Auto-trust configs to avoid interactive prompts
  mise trust --all 2>/dev/null || true
  if [ -n "${MISE_GLOBAL_CONFIG_FILE:-}" ] || [ -f "/work/mise.toml" ] || [ -f "/work/.mise.toml" ]; then
    echo "[sandbox] mise: checking shared tools in $MISE_DATA_DIR (first run may take a minute) ..."
    mise install --yes 2>&1 | sed 's/^/[mise] /' || echo "[sandbox] mise install: some tools failed (network offline?), continuing"
    mise reshim 2>/dev/null || true
  fi
fi

# Link sandbox dotfiles (bashrc, pwsh profile, gitconfig) — mise task.
# Personal overrides in /work/dotfiles win. Idempotent.
if command -v mise >/dev/null 2>&1; then
  mise run dotfiles 2>&1 | sed 's/^/[sandbox] /' || true
fi

# Ensure shims are on PATH for this session even before any profile runs
if [ -d "$MISE_DATA_DIR/shims" ]; then
  export PATH="$MISE_DATA_DIR/shims:$PATH"
fi

# ── observability: emit session start event ──────────────────────────────────
if [ -d /var/log/sandbox ]; then
  echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)\",\"event\":\"container_start\",\"user\":\"${USER:-dev}\",\"hostname\":\"$(hostname)\",\"workspace\":\"/work\"}" >> /var/log/sandbox/session-start.jsonl 2>/dev/null || true
fi

# If no command given, default is pwsh (via launcher; bash fallback offline).
# Exec so signals work.
if [ $# -eq 0 ]; then
  exec /usr/local/bin/sandbox-pwsh
else
  exec "$@"
fi
