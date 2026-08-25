#!/usr/bin/env bash
set -e

# sandbox-entrypoint.sh — runs inside the podman container as user `dev`
# Sets up mise with data dirs on the RW workspace, bootstraps default tools,
# then execs the requested command (default: bash).

export HOME=/home/dev
export MISE_DATA_DIR=/work/.mise/data
export MISE_STATE_DIR=/work/.mise/state
export MISE_CACHE_DIR=/work/.mise/cache
export MISE_CONFIG_DIR=/work/.mise/config
export XDG_DATA_HOME=/work/.mise/data
export XDG_STATE_HOME=/work/.mise/state
export XDG_CACHE_HOME=/work/.mise/cache
export XDG_CONFIG_HOME=/work/.mise/config

mkdir -p "$MISE_DATA_DIR" "$MISE_CACHE_DIR" "$MISE_STATE_DIR" "$MISE_CONFIG_DIR" 2>/dev/null || true

# Ensure HOME exists (tmpfs at /home/dev from podman)
if [ ! -f "$HOME/.bashrc" ]; then
  if [ -f /etc/sandbox/bashrc ]; then
    cp /etc/sandbox/bashrc "$HOME/.bashrc"
  else
    echo 'eval "$(mise activate bash)"' > "$HOME/.bashrc"
  fi
fi

# Point mise at the global manifest if the workspace doesn't have its own.
# mise looks for global config at $MISE_GLOBAL_CONFIG_FILE or /etc/mise/config.toml or ~/.config/mise/config.toml.
# We use MISE_GLOBAL_CONFIG_FILE to keep it explicit.
if [ ! -f "/work/mise.toml" ] && [ ! -f "/work/.mise.toml" ] && [ ! -f "/work/.config/mise/config.toml" ] && [ ! -f "$MISE_CONFIG_DIR/config.toml" ]; then
  if [ -f /etc/sandbox/mise.toml ]; then
    export MISE_GLOBAL_CONFIG_FILE=/etc/sandbox/mise.toml
  fi
fi

# Bootstrap tools (lazy, idempotent). Ignore failures so the shell still opens offline.
if command -v mise >/dev/null 2>&1; then
  # Auto-trust configs to avoid interactive prompts
  mise trust --all 2>/dev/null || true
  # Install declared tools into $MISE_DATA_DIR (/work/.mise/data → persistent)
  # This is a no-op on subsequent starts if already cached.
  if [ -n "${MISE_GLOBAL_CONFIG_FILE:-}" ] || [ -f "/work/mise.toml" ] || [ -f "/work/.mise.toml" ]; then
    echo "[sandbox] mise: installing tools into $MISE_DATA_DIR (first run may take a minute) ..."
    mise install --yes 2>&1 | sed 's/^/[mise] /' || echo "[sandbox] mise install: some tools failed (network offline?), continuing"
    # Reshim so `node`, `python`, etc. are on PATH via mise shims
    mise reshim 2>/dev/null || true
  fi
fi

# Ensure mise shims are on PATH for this session even before bashrc
if [ -d "$MISE_DATA_DIR/shims" ]; then
  export PATH="$MISE_DATA_DIR/shims:$PATH"
fi

# If no command given, default is bash (CMD). Exec so signals work.
if [ $# -eq 0 ]; then
  exec /bin/bash
else
  exec "$@"
fi
