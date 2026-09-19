#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.json}"

command -v gum >/dev/null 2>&1 || {
    echo "ERROR: gum is required"
    exit 1
}

command -v openssl >/dev/null 2>&1 || {
    echo "ERROR: openssl is required"
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required"
    exit 1
}

[[ -f "$CONFIG_FILE" ]] || {
    echo "ERROR: config file not found: $CONFIG_FILE"
    exit 1
}

password=$(gum input \
    --password \
    --prompt "New password: ")

if [[ -z "$password" ]]; then
    gum style --foreground 196 "✗ Password không được để trống"
    exit 1
fi

confirm=$(gum input \
    --password \
    --prompt "Confirm password: ")

if [[ "$password" != "$confirm" ]]; then
    gum style --foreground 196 "✗ Password không khớp"
    exit 1
fi

hash=$(
    printf '%s\n' "$password" |
        openssl passwd -6 -stdin
)

tmp_file=$(mktemp)

trap 'rm -f "$tmp_file"' EXIT

jq \
    --arg hash "$hash" \
    '.authentication.password_hash = $hash' \
    "$CONFIG_FILE" > "$tmp_file"

# Validate generated JSON before replacing the original.
jq empty "$tmp_file"

# Preserve permissions of the original config.
chmod --reference="$CONFIG_FILE" "$tmp_file"

mv "$tmp_file" "$CONFIG_FILE"

trap - EXIT

gum style \
    --border rounded \
    --border-foreground 82 \
    --padding "1 2" \
    "✓ Password hash updated"

echo "  Config: $CONFIG_FILE"
