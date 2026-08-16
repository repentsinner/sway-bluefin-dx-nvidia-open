#!/usr/bin/bash
# Auto-suspend guard (§spec:auto-suspend / §spec:auto-suspend-guard). Run by the hypridle idle listener.
# Suspends to deep S3 unless the machine is in production mode or within
# business hours (Mon-Fri 08:00-18:00 local). Manual suspend (nwg-bar
# Sleep, Mod+Shift+L) is unaffected — this guards only the idle trigger.
#
# Clock, production-flag path, and suspend command are overridable via
# environment variables so the decision matrix is testable without
# suspending the host (see test/auto-suspend.test.sh).
set -euo pipefail

PRODUCTION_FLAG="${TILEFIN_PRODUCTION_FLAG:-/etc/tilefin/production-mode}"
SUSPEND_CMD="${TILEFIN_SUSPEND_CMD:-systemctl suspend}"
dow=$((10#${TILEFIN_NOW_DOW:-$(date +%u)}))   # 1=Mon .. 7=Sun
hour=$((10#${TILEFIN_NOW_HOUR:-$(date +%H)})) # 0..23

# Production machines never auto-suspend (§spec:production-no-idle-interrupt).
if [ -e "$PRODUCTION_FLAG" ]; then
    echo "auto-suspend: production mode, holding" >&2
    exit 0
fi

# Business hours: machine assumed in interactive use (§spec:manual-suspend). 18:00 is
# outside the window, so the block is hours 08-17.
if [ "$dow" -ge 1 ] && [ "$dow" -le 5 ] && [ "$hour" -ge 8 ] && [ "$hour" -lt 18 ]; then
    echo "auto-suspend: business hours (dow=$dow hour=$hour), holding" >&2
    exit 0
fi

# shellcheck disable=SC2086 # SUSPEND_CMD is intentionally word-split into command + args
exec $SUSPEND_CMD
