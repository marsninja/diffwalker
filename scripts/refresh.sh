#!/usr/bin/env bash
# Sync the jaseci submodule to the tip of its pin branch (diffwalker-pin: upstream
# jac main plus fixes still in review), then prepare it with
# scripts/stage_compiler.sh. jac.toml's [dev] stanza makes jac use it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE_DIR="$REPO_ROOT/jaseci"

echo "==> Syncing jaseci submodule with its pin branch"
git -C "$REPO_ROOT" submodule update --init --recursive jaseci
before_sha="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"
git -C "$REPO_ROOT" submodule update --remote jaseci
git -C "$REPO_ROOT" submodule update --init --recursive jaseci
after_sha="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"

if [ "$before_sha" = "$after_sha" ]; then
    echo "    jaseci already at the pin ($after_sha)"
else
    echo "    jaseci updated: $before_sha -> $after_sha"
    echo "    note: commit the submodule bump to record the new pin"
fi

if ! command -v jac >/dev/null 2>&1; then
    echo "==> jac binary not found; install it with:"
    echo "    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash"
    exit 1
fi

bash "$REPO_ROOT/scripts/stage_compiler.sh"
echo "==> Done. jac version: $(jac --version | head -1)"
