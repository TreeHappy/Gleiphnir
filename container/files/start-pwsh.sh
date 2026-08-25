#!/usr/bin/env bash
# start-pwsh.sh → installed as /usr/local/bin/sandbox-pwsh
# Stable launcher for the sandbox's pwsh shell.
#
# pwsh itself comes from mise (shared volume), so it only exists AFTER
# `mise install` has run once. This script resolves it and execs into it;
# if it is not available yet (very first offline boot), falls back to bash.
#
# Doubles as:
#   - the container's login shell (useradd -s /usr/local/bin/sandbox-pwsh)
#   - the entrypoint's default exec target
set -u

MISE_DATA="${MISE_DATA_DIR:-/opt/mise-shared/data}"

candidates=(
  "$MISE_DATA/shims/pwsh"
)

# Also honour a mise-installed pwsh discovered via PATH (mise exec context)
if found="$(command -v pwsh 2>/dev/null)"; then
  candidates+=("$found")
fi

for cand in "${candidates[@]}"; do
  if [ -n "$cand" ] && [ -x "$cand" ]; then
    exec "$cand" -NoLogo "$@"
  fi
done

echo "[sandbox] pwsh not installed yet (first run?) — falling back to bash" >&2
exec /bin/bash "$@"
