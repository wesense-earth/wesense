#!/bin/sh
# check-bridges.sh — Poll EMQX bridge status and forwarding metrics
#
# Usage:
#   EMQX_API=http://192.168.43.11:18083 \
#   EMQX_USER=admin \
#   EMQX_PASSWORD=yourpassword \
#   ./check-bridges.sh
#
# Add -w / --watch to poll every 10 seconds:
#   ./check-bridges.sh --watch
#
# Add -i N to set the polling interval (seconds):
#   ./check-bridges.sh --watch -i 5

set -e

EMQX_API="${EMQX_API:-http://localhost:18083}"
EMQX_USER="${EMQX_USER:-admin}"
EMQX_PASSWORD="${EMQX_PASSWORD:?Set EMQX_PASSWORD to your dashboard password}"

WATCH=false
INTERVAL=10

while [ $# -gt 0 ]; do
    case "$1" in
        -w|--watch) WATCH=true; shift ;;
        -i) INTERVAL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

API_URL="${EMQX_API}/api/v5"

get_token() {
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${EMQX_USER}\",\"password\":\"${EMQX_PASSWORD}\"}" \
        "${API_URL}/login" | grep -o '"token":"[^"]*"' | cut -d'"' -f4
}

check_bridge() {
    bridge_name="$1"
    label="$2"

    response=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "${API_URL}/bridges/mqtt:${bridge_name}" 2>/dev/null)

    echo "$response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    status = d.get('status', 'unknown')
    m = d.get('metrics', {})
    matched = m.get('matched', 0)
    success = m.get('success', 0)
    failed = m.get('failed', 0)
    queued = m.get('queuing', 0)
    print('  %-30s  status: %-12s  matched: %-6s  sent: %-6s  failed: %-6s  queued: %s' % ('$label', status, matched, success, failed, queued))
except Exception as e:
    print('  %-30s  ERROR: %s' % ('$label', e))
"
}

poll() {
    TOKEN=$(get_token)
    if [ -z "$TOKEN" ]; then
        echo "ERROR: Login failed. Check EMQX_API, EMQX_USER, EMQX_PASSWORD."
        exit 1
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S')  EMQX Bridge Status  (${EMQX_API})"
    check_bridge "forward_meshtastic_default" "meshtastic.org"
    check_bridge "forward_cottle_map_uplink" "cottle map (uplink)"
}

if [ "$WATCH" = true ]; then
    echo "Polling every ${INTERVAL}s — Ctrl+C to stop"
    echo ""
    while true; do
        poll
        echo ""
        sleep "$INTERVAL"
    done
else
    poll
fi
