#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PLUGINS_JSON="$ROOT/plugins.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

fail=0

# 1. Same set of plugin names.
plugins_names=$(jq -r '.plugins[].name' "$PLUGINS_JSON" | sort)
marketplace_names=$(jq -r '.plugins[].name' "$MARKETPLACE_JSON" | sort)

diff_output=$(diff <(echo "$plugins_names") <(echo "$marketplace_names") || true)

if [ -n "$diff_output" ]; then
    echo "ERROR: plugins.json and marketplace.json plugin lists differ:" >&2
    echo "$diff_output" >&2
    fail=1
fi

# Normalize a repository identifier to "owner/repo" form regardless of whether
# the source is a short slug or an https github URL with optional .git suffix.
normalize_repo() {
    echo "$1" | sed -E 's|^https?://github\.com/||; s|\.git$||; s|/$||'
}

# 2. For each plugin present in both files, verify cross-file alignment.
while read -r name; do
    [ -z "$name" ] && continue

    pj_repo=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .repository' "$PLUGINS_JSON")
    mp_url=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .source.url' "$MARKETPLACE_JSON")

    pj_norm=$(normalize_repo "$pj_repo")
    mp_norm=$(normalize_repo "$mp_url")

    if [ "$pj_norm" != "$mp_norm" ]; then
        echo "ERROR: '$name' repository mismatch: plugins.json='$pj_norm' marketplace.json='$mp_norm'" >&2
        fail=1
    fi

    # 3. If plugins.json description embeds a vX.Y.Z marker, it must equal the
    #    typed version in marketplace.json. Descriptions without a marker are
    #    allowed (e.g. plugins that never embedded a version).
    pj_desc=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .description // ""' "$PLUGINS_JSON")
    mp_ver=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .version // ""' "$MARKETPLACE_JSON")

    embedded_ver=$(echo "$pj_desc" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?' | tail -n 1 || true)
    if [ -n "$embedded_ver" ] && [ -n "$mp_ver" ]; then
        embedded_norm="${embedded_ver#v}"
        if [ "$embedded_norm" != "$mp_ver" ]; then
            echo "ERROR: '$name' version mismatch: plugins.json description='$embedded_ver' marketplace.json version='$mp_ver'" >&2
            fail=1
        fi
    fi
done <<< "$plugins_names"

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "OK: plugins.json and marketplace.json are in sync (names, repos, versions)"
