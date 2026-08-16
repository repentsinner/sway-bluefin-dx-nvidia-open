#!/usr/bin/bash
# Decision-matrix test for the §spec:auto-suspend auto-suspend guard (§spec:auto-suspend-guard).
# Exercises the guard with overridden clock/flag/suspend-cmd so the
# decision is verified without suspending the host.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/build_files/auto-suspend.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

NOFLAG="$TMP/absent"            # production flag absent -> development mode
PRODFLAG="$TMP/production"; : > "$PRODFLAG"

fail=0
# check <suspend|hold> <description> <env assignments...>
check() {
    expect="$1"; desc="$2"; shift 2
    out="$(env "$@" TILEFIN_SUSPEND_CMD='echo SUSPEND' "$SCRIPT" 2>/dev/null)"
    got="hold"; [ "$out" = "SUSPEND" ] && got="suspend"
    if [ "$got" = "$expect" ]; then
        printf 'ok   - %s\n' "$desc"
    else
        printf 'FAIL - %s (expected %s, got %s)\n' "$desc" "$expect" "$got"
        fail=1
    fi
}

# Production mode: never auto-suspends (§spec:production-no-idle-interrupt).
check hold    "production + after-hours"   TILEFIN_PRODUCTION_FLAG="$PRODFLAG" TILEFIN_NOW_DOW=6 TILEFIN_NOW_HOUR=22
check hold    "production + business hours" TILEFIN_PRODUCTION_FLAG="$PRODFLAG" TILEFIN_NOW_DOW=2 TILEFIN_NOW_HOUR=14

# Development mode, business hours (Mon-Fri 08:00-18:00): hold.
check hold    "Tue 14:00 mid-day"          TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=2 TILEFIN_NOW_HOUR=14
check hold    "Mon 08:00 start boundary"   TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=1 TILEFIN_NOW_HOUR=8
check hold    "Fri 17:00 last work hour"   TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=5 TILEFIN_NOW_HOUR=17

# Development mode, outside business hours: suspend.
check suspend "Tue 07:00 pre-hours"        TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=2 TILEFIN_NOW_HOUR=7
check suspend "Fri 18:00 end boundary"     TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=5 TILEFIN_NOW_HOUR=18
check suspend "Wed 23:00 night"            TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=3 TILEFIN_NOW_HOUR=23
check suspend "Sat 14:00 weekend"          TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=6 TILEFIN_NOW_HOUR=14
check suspend "Sun 10:00 weekend"          TILEFIN_PRODUCTION_FLAG="$NOFLAG" TILEFIN_NOW_DOW=7 TILEFIN_NOW_HOUR=10

if [ "$fail" -eq 0 ]; then
    echo "PASS"
else
    echo "FAILURES"
    exit 1
fi
