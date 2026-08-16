#!/bin/bash
# Waybar module: show image age (fuzzy) and update availability

# Production-mode flag (§spec:production-mode). Toggled by `ujust production-mode --start|--stop`.
if [ -f /etc/tilefin/production-mode ]; then
    MODE="production"
else
    MODE="development"
fi

fuzzy_age() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((seconds / 3600))
    local days=$((seconds / 86400))
    local weeks=$((seconds / 604800))

    if [ "$minutes" -lt 1 ]; then
        echo "now"
    elif [ "$minutes" -lt 60 ]; then
        echo "${minutes}min"
    elif [ "$hours" -lt 24 ]; then
        echo "${hours}hr"
    elif [ "$days" -lt 14 ]; then
        echo "${days}d"
    else
        echo "${weeks}wk"
    fi
}

STATUS_JSON=$(rpm-ostree status --json 2>/dev/null)
if [ -z "$STATUS_JSON" ]; then
    echo '{"text": "", "tooltip": "Unable to get image status"}'
    exit 0
fi

NOW=$(date +%s)

# Booted deployment
BOOTED_VERSION=$(echo "$STATUS_JSON" | jq -r '[.deployments[] | select(.booted)][0].version // empty')
BOOTED_TS=$(echo "$STATUS_JSON" | jq -r '[.deployments[] | select(.booted)][0].timestamp // empty')
BOOTED_IMAGE=$(echo "$STATUS_JSON" | jq -r '[.deployments[] | select(.booted)][0]."container-image-reference" // empty' | sed 's/^ostree-unverified-registry://')

# Staged deployment
STAGED_VERSION=$(echo "$STATUS_JSON" | jq -r '[.deployments[] | select(.staged)][0].version // empty')
STAGED_TS=$(echo "$STATUS_JSON" | jq -r '[.deployments[] | select(.staged)][0].timestamp // empty')
STAGED_IMAGE=$(echo "$STATUS_JSON" | jq -r '[.deployments[] | select(.staged)][0]."container-image-reference" // empty' | sed 's/^ostree-unverified-registry://')

# Age of booted image
AGE=""
if [ -n "$BOOTED_TS" ]; then
    AGE=$(fuzzy_age $((NOW - BOOTED_TS)))
fi

if [ -n "$STAGED_VERSION" ] && [ "$STAGED_TS" != "$BOOTED_TS" ]; then
    STAGED_AGE=$(fuzzy_age $((NOW - STAGED_TS)))
    BOOTED_AGE_SECS=$((NOW - BOOTED_TS))
    TEXT=" ${MODE} · ${AGE}"

    # Package diff between booted and staged deployments
    # Output format: section headers (Upgraded:, Added:, etc.) followed by indented package lines
    PKG_DIFF=$(rpm-ostree db diff 2>/dev/null)
    count_section() { echo "$PKG_DIFF" | awk "/^${1}:/{f=1;next} /^[A-Z]/{f=0} f&&/^ /{c++} END{print c+0}"; }
    PKG_UPGRADED=$(count_section Upgraded)
    PKG_ADDED=$(count_section Added)
    PKG_REMOVED=$(count_section Removed)
    PKG_DOWNGRADED=$(count_section Downgraded)
    PKG_TOTAL=$((PKG_ADDED + PKG_REMOVED + PKG_UPGRADED + PKG_DOWNGRADED))

    PKG_SUMMARY=""
    if [ "$PKG_TOTAL" -gt 0 ]; then
        PKG_PARTS=""
        [ "$PKG_UPGRADED" -gt 0 ] && PKG_PARTS="${PKG_UPGRADED} upgraded"
        [ "$PKG_ADDED" -gt 0 ] && PKG_PARTS="${PKG_PARTS:+${PKG_PARTS}, }${PKG_ADDED} added"
        [ "$PKG_REMOVED" -gt 0 ] && PKG_PARTS="${PKG_PARTS:+${PKG_PARTS}, }${PKG_REMOVED} removed"
        [ "$PKG_DOWNGRADED" -gt 0 ] && PKG_PARTS="${PKG_PARTS:+${PKG_PARTS}, }${PKG_DOWNGRADED} downgraded"
        PKG_SUMMARY="\nPackages: ${PKG_PARTS}"

        # Show up to 5 upgraded package names
        PKG_NAMES=$(echo "$PKG_DIFF" | awk '/^Upgraded:/{f=1;next} /^[A-Z]/{f=0} f&&/^ /{gsub(/^ +/,""); sub(/ .*/,""); print}' | head -5)
        if [ -n "$PKG_NAMES" ]; then
            PKG_LIST=$(echo "$PKG_NAMES" | sed 's/^/  /' | tr '\n' '|' | sed 's/|/\\n/g; s/\\n$//')
            PKG_SUMMARY="${PKG_SUMMARY}\n${PKG_LIST}"
            [ "$PKG_UPGRADED" -gt 5 ] && PKG_SUMMARY="${PKG_SUMMARY}\n  ... +$(( PKG_UPGRADED - 5 )) more"
        fi
    fi

    TOOLTIP="Mode: ${MODE}\nBooted: ${BOOTED_VERSION} (${AGE} ago)\nStaged: ${STAGED_VERSION} (${STAGED_AGE} ago)\nImage: ${STAGED_IMAGE}${PKG_SUMMARY}\nReboot to apply"
    if [ "$BOOTED_AGE_SECS" -ge 172800 ]; then
        CLASS="update-stale"
    else
        CLASS="update-available"
    fi
else
    TEXT="${MODE} · ${AGE}"
    TOOLTIP="Mode: ${MODE}\nImage: ${BOOTED_IMAGE}\nVersion: ${BOOTED_VERSION}\nBuilt: $(date -d @"$BOOTED_TS" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    CLASS=""
fi

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
