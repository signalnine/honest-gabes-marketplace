#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PLUGINS_JSON="$ROOT/plugins.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

plugins_names=$(jq -r '.plugins[].name' "$PLUGINS_JSON" | sort)
marketplace_names=$(jq -r '.plugins[].name' "$MARKETPLACE_JSON" | sort)

diff_output=$(diff <(echo "$plugins_names") <(echo "$marketplace_names") || true)

if [ -n "$diff_output" ]; then
    echo "ERROR: plugins.json and marketplace.json are out of sync:" >&2
    echo "$diff_output" >&2
    exit 1
fi

echo "OK: plugins.json and marketplace.json list the same plugins"
