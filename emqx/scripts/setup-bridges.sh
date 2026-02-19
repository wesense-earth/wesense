#!/bin/sh
# setup-bridges.sh — Configure EMQX MQTT bridges for Tier 1 forwarding
#
# Creates egress bridges that forward all msh/# traffic from mqtt.wesense.earth
# to community Meshtastic infrastructure, so users who point their devices to
# WeSense don't lose visibility on other maps.
#
# Usage:
#   EMQX_API=http://localhost:18083 \
#   EMQX_USER=admin \
#   EMQX_PASSWORD=yourpassword \
#   ./setup-bridges.sh
#
# Or from a remote machine:
#   EMQX_API=http://192.168.43.13:18083 EMQX_USER=admin EMQX_PASSWORD=yourpassword ./setup-bridges.sh
#
# Prerequisites:
#   - EMQX must be running with the dashboard accessible
#   - curl must be installed
#
# What this creates:
#   1. Bridge to mqtt.meshtastic.org (default Meshtastic infrastructure)
#   2. Bridge to mqtt.meshtastic.liamcottle.net (Liam Cottle map uplink)
#
# These are Tier 1 bridges — always on, forward ALL msh/# unconditionally.
# No per-user filtering, no accounts needed.
#
# Bridge config is persisted in EMQX's data directory and survives restarts.

set -e

# --- Configuration ---
EMQX_API="${EMQX_API:-http://localhost:18083}"
EMQX_USER="${EMQX_USER:-admin}"
EMQX_PASSWORD="${EMQX_PASSWORD:?Set EMQX_PASSWORD to your dashboard password}"

API_URL="${EMQX_API}/api/v5"

# --- Auth: obtain JWT token ---
echo "Authenticating with EMQX at ${EMQX_API}..."
login_response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${EMQX_USER}\",\"password\":\"${EMQX_PASSWORD}\"}" \
    "${API_URL}/login" 2>/dev/null)

login_code=$(echo "$login_response" | tail -n1)
login_body=$(echo "$login_response" | sed '$d')

if [ "$login_code" != "200" ]; then
    echo "ERROR: Login failed (HTTP $login_code)"
    echo "$login_body"
    exit 1
fi

TOKEN=$(echo "$login_body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not extract token from login response"
    exit 1
fi
echo "Authenticated OK"

AUTH_HEADER="Authorization: Bearer $TOKEN"

# --- Helper ---
create_bridge() {
    bridge_name="$1"
    bridge_json="$2"

    echo ""
    echo "=== Creating bridge: $bridge_name ==="

    # Check if bridge already exists
    status=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "$AUTH_HEADER" \
        "${API_URL}/bridges/mqtt:${bridge_name}")

    if [ "$status" = "200" ]; then
        echo "Bridge '$bridge_name' already exists. Updating..."
        response=$(curl -s -w "\n%{http_code}" \
            -X PUT \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$bridge_json" \
            "${API_URL}/bridges/mqtt:${bridge_name}")
    else
        echo "Creating new bridge '$bridge_name'..."
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$bridge_json" \
            "${API_URL}/bridges")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    case "$http_code" in
        200|201)
            echo "OK ($http_code)"
            bridge_status=$(echo "$body" | grep -o '"status":"[^"]*"' | head -1 || true)
            echo "  $bridge_status"
            ;;
        *)
            echo "FAILED ($http_code)"
            echo "$body" | head -20
            return 1
            ;;
    esac
}

# --- Bridge 1: mqtt.meshtastic.org ---
# Default Meshtastic MQTT server. All msh/# traffic forwarded here so users
# who point to mqtt.wesense.earth still appear on the default Meshtastic map
# infrastructure.
create_bridge "forward_meshtastic_default" '{
  "type": "mqtt",
  "name": "forward_meshtastic_default",
  "server": "mqtt.meshtastic.org:1883",
  "username": "meshdev",
  "password": "large4cats",
  "proto_ver": "v4",
  "clean_start": true,
  "keepalive": "60s",
  "egress": {
    "local": {
      "topic": "msh/#"
    },
    "remote": {
      "topic": "${topic}",
      "payload": "${payload}",
      "qos": 1,
      "retain": false
    }
  },
  "resource_opts": {
    "worker_pool_size": 4,
    "health_check_interval": "30s",
    "auto_restart_interval": "30s"
  }
}'

# --- Bridge 2: Liam Cottle Map Uplink ---
# Uses the uplink-only endpoint specifically designed for pushing data to
# Liam Cottle's Meshtastic map. The uplink/uplink credentials are the standard
# uplink-only access — this avoids topology corruption issues (phantom node
# connection lines) that can occur when using the full mqtt.meshtastic.org bridge.
create_bridge "forward_cottle_map_uplink" '{
  "type": "mqtt",
  "name": "forward_cottle_map_uplink",
  "server": "mqtt.meshtastic.liamcottle.net:1883",
  "username": "uplink",
  "password": "uplink",
  "proto_ver": "v4",
  "clean_start": true,
  "keepalive": "60s",
  "egress": {
    "local": {
      "topic": "msh/#"
    },
    "remote": {
      "topic": "${topic}",
      "payload": "${payload}",
      "qos": 1,
      "retain": false
    }
  },
  "resource_opts": {
    "worker_pool_size": 4,
    "health_check_interval": "30s",
    "auto_restart_interval": "30s"
  }
}'

# --- Summary ---
echo ""
echo "=== Bridge Setup Complete ==="
echo ""
echo "Tier 1 bridges configured:"
echo "  1. forward_meshtastic_default  -> mqtt.meshtastic.org:1883"
echo "  2. forward_cottle_map_uplink   -> mqtt.meshtastic.liamcottle.net:1883"
echo ""
echo "Both bridges forward all msh/# traffic from this EMQX instance."
echo "Messages published by devices pointing to mqtt.wesense.earth will"
echo "automatically appear on the default Meshtastic map and Liam Cottle's map."
echo ""
echo "To verify in the dashboard:"
echo "  ${EMQX_API} -> Integration -> Data Bridge"
echo ""
echo "To test: publish a test message to msh/ANZ/test and check if it"
echo "appears on the remote brokers."
