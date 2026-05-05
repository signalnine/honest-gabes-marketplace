#!/usr/bin/env bash
# Schema validation for plugins.json and .claude-plugin/marketplace.json.
# jq empty only verifies that JSON parses; this script enforces required
# fields and shapes so a PR that drops e.g. source.url cannot pass CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS_JSON="$ROOT/plugins.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

fail=0
err() { echo "ERROR: $*" >&2; fail=1; }

# marketplace.json: top-level shape
jq -e '.plugins | type == "array" and length > 0' "$MARKETPLACE_JSON" >/dev/null \
    || err "marketplace.json: .plugins must be a non-empty array"

# marketplace.json: per-plugin required fields
mp_count=$(jq '.plugins | length' "$MARKETPLACE_JSON")
for ((i=0; i<mp_count; i++)); do
    name=$(jq -r ".plugins[$i].name // empty" "$MARKETPLACE_JSON")
    url=$(jq -r ".plugins[$i].source.url // empty" "$MARKETPLACE_JSON")
    src=$(jq -r ".plugins[$i].source.source // empty" "$MARKETPLACE_JSON")
    ver=$(jq -r ".plugins[$i].version // empty" "$MARKETPLACE_JSON")

    [ -n "$name" ] || err "marketplace.json: plugin[$i] missing 'name'"
    [ -n "$url" ]  || err "marketplace.json: plugin[$i] ('${name:-?}') missing 'source.url'"
    [ -n "$src" ]  || err "marketplace.json: plugin[$i] ('${name:-?}') missing 'source.source'"
    [ -n "$ver" ]  || err "marketplace.json: plugin[$i] ('${name:-?}') missing 'version'"

    if [ -n "$ver" ] && ! [[ "$ver" =~ $SEMVER_RE ]]; then
        err "marketplace.json: plugin '$name' version '$ver' is not valid semver"
    fi
done

# marketplace.json: no duplicate plugin names
dupes=$(jq -r '.plugins | group_by(.name) | map(select(length > 1)) | .[][0].name' "$MARKETPLACE_JSON")
if [ -n "$dupes" ]; then
    while IFS= read -r d; do
        [ -n "$d" ] && err "marketplace.json: duplicate plugin name '$d'"
    done <<< "$dupes"
fi

# plugins.json: top-level shape
jq -e '.plugins | type == "array" and length > 0' "$PLUGINS_JSON" >/dev/null \
    || err "plugins.json: .plugins must be a non-empty array"

# plugins.json: per-plugin required fields
pj_count=$(jq '.plugins | length' "$PLUGINS_JSON")
for ((i=0; i<pj_count; i++)); do
    name=$(jq -r ".plugins[$i].name // empty" "$PLUGINS_JSON")
    repo=$(jq -r ".plugins[$i].repository // empty" "$PLUGINS_JSON")

    [ -n "$name" ] || err "plugins.json: plugin[$i] missing 'name'"
    [ -n "$repo" ] || err "plugins.json: plugin[$i] ('${name:-?}') missing 'repository'"
done

# plugins.json: no duplicate plugin names
dupes=$(jq -r '.plugins | group_by(.name) | map(select(length > 1)) | .[][0].name' "$PLUGINS_JSON")
if [ -n "$dupes" ]; then
    while IFS= read -r d; do
        [ -n "$d" ] && err "plugins.json: duplicate plugin name '$d'"
    done <<< "$dupes"
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "OK: schema validation passed (required fields present, versions semver, no duplicate names)"
