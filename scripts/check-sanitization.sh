#!/usr/bin/env bash
# check-sanitization.sh — bundle-wide sanitization gate.
#
# Run this BEFORE every commit in ~/Projects/hermes-starter-bundle/.
# Fails (exit 1) if any of the 5 leak classes is present.
#
# Companion to dotfile-config-editing/references/incremental-bundle-update.md
# (Rule 9). The references explain the WHY; this script is the HOW.
#
# Idempotent. Safe to run repeatedly. Reads the bundle path from
# its own location, not from /Users/jay/... — works on any dev box.

set -euo pipefail

# Resolve bundle dir from script location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$BUNDLE_DIR" || { echo "Could not cd to $BUNDLE_DIR"; exit 2; }

LEAKS=0

# Helper: run a grep, filter .git/ + this script + fenced code blocks
# in markdown files (so the recipe's own example greps don't trigger
# false positives). Returns hits or empty.
#
# The fence filter: skip lines that are inside ```...``` code blocks.
# For each file, we track whether we're inside a fence; only emit hits
# that are outside fences.
check() {
    local label="$1"
    local pattern="$2"
    local hits
    hits=$(awk -v pat="$pattern" '
        BEGIN { in_fence = 0 }
        /^```/ { in_fence = !in_fence; next }
        in_fence { next }
        # Skip this script (it carries the patterns as data).
        FILENAME ~ /check-sanitization\.sh$/ { next }
        # Skip the .git/ directory entirely.
        FILENAME ~ /\/\.git\// { next }
        # Run the grep.
        $0 ~ pat { print FILENAME ":" FNR ":" $0 }
    ' $(find . -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.py" -o -name "*.sh" -o -name "*.template" -o -name "*.json" -o -name "*.txt" \) 2>/dev/null) 2>/dev/null || true)
    if [ -n "$hits" ]; then
        echo "LEAK [$label]:"
        echo "$hits" | head -10
        # If more than 10, note the count.
        local total
        total=$(echo "$hits" | wc -l | tr -d ' ')
        if [ "$total" -gt 10 ]; then
            echo "  ... and $((total - 10)) more"
        fi
        echo ""
        LEAKS=$((LEAKS + 1))
    fi
}

echo "Sanitization check for $BUNDLE_DIR"
echo "======================================"
echo ""

# 1. Personal names / usernames
check "personal-name" \
    "(jay|jnthn|jonathan|john\.kumple|kumple)"

# 2. LAN hostnames / private IPs
check "lan-host-or-ip" \
    "(mini\.lan|git\.mini|192\.168\.[0-9]+\.[0-9]+|10\.0\.[0-9]+\.[0-9]+)"

# 3. Chat IDs / phone numbers / @-handles
check "chat-id-or-handle" \
    "(chat_id[ =:][^\"']*[0-9]{8,}|telegram:[0-9-]{8,}|discord:[0-9]{8,}|@[a-z_0-9]+bot)"

# 4. API keys / tokens / long secret-shaped strings
check "secret-shaped-string" \
    "(sk-[A-Za-z0-9]{20,}|sk_live_|bearer [a-zA-Z0-9]{20,}|api[_-]?key[ =:][\"'][a-zA-Z0-9-]{20,})"

# 5. Personal filesystem paths
check "personal-path" \
    "(/Users/jay|/Users/jnthn)"

# 6. GitHub-username references (the 6th grep that catches
#    what Rule 9's one-liner misses — see "Pitfall — generic
#    reference" in the reference).
#    Adjust <github-username> to your actual GitHub username,
#    OR leave the placeholder if you don't want this check
#    to run.
GITHUB_USER="jotokra"  # <-- set to your GitHub username, or empty to skip
if [ -n "$GITHUB_USER" ]; then
    check "github-username-ref" \
        "(@${GITHUB_USER}|github\.com/${GITHUB_USER})"
fi

echo "======================================"
if [ "$LEAKS" -gt 0 ]; then
    echo "✗ $LEAKS class(es) of leak found. DO NOT COMMIT."
    exit 1
fi

echo "✓ All sanitization checks passed."
exit 0
