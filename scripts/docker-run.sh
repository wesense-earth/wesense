#!/usr/bin/env bash
# Generate docker run commands for WeSense services
# Usage: ./scripts/docker-run.sh [persona|service]
#
# Examples:
#   ./scripts/docker-run.sh station       # Show all commands for station persona
#   ./scripts/docker-run.sh contributor   # Show commands for contributor persona
#   ./scripts/docker-run.sh emqx          # Show command for specific service
#   ./scripts/docker-run.sh               # Show usage
#
# This script is useful for:
#   - Unraid (which doesn't support docker-compose)
#   - Manual deployments
#   - Understanding what docker-compose does under the hood
#
# See Deployment_Personas.md for full persona details

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Default values (matching .env.sample defaults)
TZ="${TZ:-Pacific/Auckland}"
PORT_MQTT_PLAIN="${PORT_MQTT_PLAIN:-1883}"
PORT_MQTT_TLS="${PORT_MQTT_TLS:-8883}"
PORT_WS_PLAIN="${PORT_WS_PLAIN:-8083}"
PORT_WS_TLS="${PORT_WS_TLS:-8084}"
PORT_DASHBOARD="${PORT_DASHBOARD:-18083}"
PORT_CLICKHOUSE_HTTP="${PORT_CLICKHOUSE_HTTP:-8123}"
PORT_CLICKHOUSE_NATIVE="${PORT_CLICKHOUSE_NATIVE:-9000}"
PORT_RESPIRO="${PORT_RESPIRO:-3000}"
PORT_TTN_WEBHOOK="${PORT_TTN_WEBHOOK:-5000}"
TLS_MQTT_ENABLED="${TLS_MQTT_ENABLED:-false}"
TLS_WS_ENABLED="${TLS_WS_ENABLED:-false}"
TLS_CERTFILE="${TLS_CERTFILE:-/opt/emqx/etc/certs/fullchain.pem}"
TLS_KEYFILE="${TLS_KEYFILE:-/opt/emqx/etc/certs/privkey.pem}"
CLICKHOUSE_DB="${CLICKHOUSE_DB:-wesense}"
CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-}"
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-clickhouse}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-8123}"
CLICKHOUSE_BATCH_SIZE="${CLICKHOUSE_BATCH_SIZE:-100}"
CLICKHOUSE_FLUSH_INTERVAL="${CLICKHOUSE_FLUSH_INTERVAL:-10}"
LOCAL_MQTT_HOST="${LOCAL_MQTT_HOST:-emqx}"
LOCAL_MQTT_PORT="${LOCAL_MQTT_PORT:-1883}"
LOCAL_MQTT_USER="${LOCAL_MQTT_USER:-}"
LOCAL_MQTT_PASSWORD="${LOCAL_MQTT_PASSWORD:-}"
MESHTASTIC_MODE="${MESHTASTIC_MODE:-public}"
DEBUG="${DEBUG:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
TTN_WEBHOOK_ENABLED="${TTN_WEBHOOK_ENABLED:-false}"
TTN_WEBHOOK_PORT="${TTN_WEBHOOK_PORT:-5000}"
HA_URL="${HA_URL:-http://homeassistant.local:8123}"
HA_ACCESS_TOKEN="${HA_ACCESS_TOKEN:-}"
HA_NODE_NAME="${HA_NODE_NAME:-}"
DISABLE_CLICKHOUSE="${DISABLE_CLICKHOUSE:-false}"
INGESTER_MESHTASTIC_IMAGE="${INGESTER_MESHTASTIC_IMAGE:-ghcr.io/wesense-earth/wesense-ingester-meshtastic:latest}"
INGESTER_WESENSE_IMAGE="${INGESTER_WESENSE_IMAGE:-ghcr.io/wesense-earth/wesense-ingester-wesense:latest}"
INGESTER_HA_IMAGE="${INGESTER_HA_IMAGE:-ghcr.io/wesense-earth/wesense-ingester-homeassistant:latest}"
RESPIRO_IMAGE="${RESPIRO_IMAGE:-ghcr.io/wesense-earth/wesense-respiro:latest}"
MAP_CENTER_LAT="${MAP_CENTER_LAT:--36.848}"
MAP_CENTER_LNG="${MAP_CENTER_LNG:-174.763}"
MAP_ZOOM_LEVEL="${MAP_ZOOM_LEVEL:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}# ========================================${NC}"
    echo -e "${BLUE}# $1${NC}"
    echo -e "${BLUE}# ========================================${NC}"
}

print_network() {
    echo -e "${YELLOW}# Create network first (if not exists):${NC}"
    echo "docker network create wesense-net 2>/dev/null || true"
    echo ""
}

generate_emqx() {
    print_header "EMQX - MQTT Broker"
    cat << EOF
docker run -d \\
  --name wesense-emqx \\
  --network wesense-net \\
  --restart unless-stopped \\
  -p ${PORT_MQTT_PLAIN}:1883 \\
  -p ${PORT_MQTT_TLS}:8883 \\
  -p ${PORT_WS_PLAIN}:8083 \\
  -p ${PORT_WS_TLS}:8084 \\
  -p ${PORT_DASHBOARD}:18083 \\
  -v wesense-emqx-data:/opt/emqx/data \\
  -v wesense-emqx-log:/opt/emqx/log \\
  -v ${PROJECT_DIR}/certs:/opt/emqx/etc/certs:ro \\
  -v ${PROJECT_DIR}/emqx/etc/emqx.conf:/opt/emqx/etc/emqx.conf:ro \\
  -e EMQX_LISTENERS__SSL__DEFAULT__ENABLED=${TLS_MQTT_ENABLED} \\
  -e EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__CERTFILE=${TLS_CERTFILE} \\
  -e EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__KEYFILE=${TLS_KEYFILE} \\
  -e EMQX_LISTENERS__WSS__DEFAULT__ENABLED=${TLS_WS_ENABLED} \\
  -e EMQX_LISTENERS__WSS__DEFAULT__SSL_OPTIONS__CERTFILE=${TLS_CERTFILE} \\
  -e EMQX_LISTENERS__WSS__DEFAULT__SSL_OPTIONS__KEYFILE=${TLS_KEYFILE} \\
  -e TZ=${TZ} \\
  emqx/emqx:5
EOF
    echo ""
}

generate_clickhouse() {
    print_header "ClickHouse - Time Series Database"
    cat << EOF
docker run -d \\
  --name wesense-clickhouse \\
  --network wesense-net \\
  --restart unless-stopped \\
  -p ${PORT_CLICKHOUSE_HTTP}:8123 \\
  -p ${PORT_CLICKHOUSE_NATIVE}:9000 \\
  -v wesense-clickhouse-data:/var/lib/clickhouse \\
  -v wesense-clickhouse-logs:/var/log/clickhouse-server \\
  -v ${PROJECT_DIR}/clickhouse/init:/docker-entrypoint-initdb.d:ro \\
  -e CLICKHOUSE_DB=${CLICKHOUSE_DB} \\
  -e CLICKHOUSE_USER=${CLICKHOUSE_USER} \\
  -e CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD} \\
  -e TZ=${TZ} \\
  --ulimit nproc=65535 \\
  --ulimit nofile=262144:262144 \\
  clickhouse/clickhouse-server:24
EOF
    echo ""
}

generate_ingester_meshtastic() {
    print_header "Meshtastic Ingester (public + community)"
    cat << EOF
docker run -d \\
  --name wesense-ingester-meshtastic \\
  --network wesense-net \\
  --restart unless-stopped \\
  -v ${PROJECT_DIR}/ingester-meshtastic/cache:/app/cache \\
  -v ${PROJECT_DIR}/ingester-meshtastic/config:/app/config:ro \\
  -v ${PROJECT_DIR}/ingester-meshtastic/logs:/app/logs \\
  -e MESHTASTIC_MODE=${MESHTASTIC_MODE} \\
  -e CLICKHOUSE_HOST=${CLICKHOUSE_HOST} \\
  -e CLICKHOUSE_PORT=${CLICKHOUSE_PORT} \\
  -e CLICKHOUSE_DATABASE=${CLICKHOUSE_DB} \\
  -e CLICKHOUSE_BATCH_SIZE=${CLICKHOUSE_BATCH_SIZE} \\
  -e CLICKHOUSE_FLUSH_INTERVAL=${CLICKHOUSE_FLUSH_INTERVAL} \\
  -e WESENSE_OUTPUT_BROKER=${LOCAL_MQTT_HOST} \\
  -e WESENSE_OUTPUT_PORT=${LOCAL_MQTT_PORT} \\
  -e WESENSE_OUTPUT_USERNAME=${LOCAL_MQTT_USER} \\
  -e WESENSE_OUTPUT_PASSWORD=${LOCAL_MQTT_PASSWORD} \\
  -e DEBUG=${DEBUG} \\
  -e LOG_LEVEL=${LOG_LEVEL} \\
  -e TZ=${TZ} \\
  ${INGESTER_MESHTASTIC_IMAGE}
EOF
    echo ""
}

generate_ingester_wesense() {
    print_header "WeSense Ingester (WiFi + LoRa + TTN webhook)"
    cat << EOF
docker run -d \\
  --name wesense-ingester-wesense \\
  --network wesense-net \\
  --restart unless-stopped \\
  -v wesense-ingester-wesense-cache:/app/cache \\
  -v wesense-ingester-wesense-logs:/app/logs \\
  -e MQTT_BROKER=${LOCAL_MQTT_HOST} \\
  -e MQTT_PORT=${LOCAL_MQTT_PORT} \\
  -e MQTT_USERNAME=${LOCAL_MQTT_USER} \\
  -e MQTT_PASSWORD=${LOCAL_MQTT_PASSWORD} \\
  -e CLICKHOUSE_HOST=${CLICKHOUSE_HOST} \\
  -e CLICKHOUSE_PORT=${CLICKHOUSE_PORT} \\
  -e CLICKHOUSE_DATABASE=${CLICKHOUSE_DB} \\
  -e CLICKHOUSE_BATCH_SIZE=${CLICKHOUSE_BATCH_SIZE} \\
  -e CLICKHOUSE_FLUSH_INTERVAL=${CLICKHOUSE_FLUSH_INTERVAL} \\
  -e WESENSE_OUTPUT_BROKER=${LOCAL_MQTT_HOST} \\
  -e WESENSE_OUTPUT_PORT=${LOCAL_MQTT_PORT} \\
  -e WESENSE_OUTPUT_USERNAME=${LOCAL_MQTT_USER} \\
  -e WESENSE_OUTPUT_PASSWORD=${LOCAL_MQTT_PASSWORD} \\
  -e TTN_WEBHOOK_ENABLED=${TTN_WEBHOOK_ENABLED} \\
  -e TTN_WEBHOOK_PORT=${TTN_WEBHOOK_PORT} \\
  -e DEBUG=${DEBUG} \\
  -e TZ=${TZ} \\
  -p ${PORT_TTN_WEBHOOK}:5000 \\
  ${INGESTER_WESENSE_IMAGE}
EOF
    echo ""
}

generate_ingester_homeassistant() {
    print_header "Home Assistant Ingester"
    cat << EOF
docker run -d \\
  --name wesense-ingester-homeassistant \\
  --network wesense-net \\
  --restart unless-stopped \\
  -v ${PROJECT_DIR}/ingester-homeassistant/config:/app/config:ro \\
  -v wesense-ingester-ha-logs:/app/logs \\
  -e HA_URL=${HA_URL} \\
  -e HA_ACCESS_TOKEN=${HA_ACCESS_TOKEN} \\
  -e NODE_NAME=${HA_NODE_NAME} \\
  -e CLICKHOUSE_HOST=${CLICKHOUSE_HOST} \\
  -e CLICKHOUSE_PORT=${CLICKHOUSE_PORT} \\
  -e CLICKHOUSE_DATABASE=${CLICKHOUSE_DB} \\
  -e CLICKHOUSE_USER=${CLICKHOUSE_USER} \\
  -e CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD} \\
  -e LOCAL_MQTT_BROKER=${LOCAL_MQTT_HOST} \\
  -e LOCAL_MQTT_PORT=${LOCAL_MQTT_PORT} \\
  -e DISABLE_CLICKHOUSE=${DISABLE_CLICKHOUSE} \\
  -e LOG_LEVEL=${LOG_LEVEL} \\
  -e TZ=${TZ} \\
  ${INGESTER_HA_IMAGE}
EOF
    echo ""
}

generate_respiro() {
    print_header "Respiro - Environmental Sensor Map"
    cat << EOF
docker run -d \\
  --name wesense-respiro \\
  --network wesense-net \\
  --restart unless-stopped \\
  -p ${PORT_RESPIRO}:3000 \\
  -v ${PROJECT_DIR}/respiro/data:/app/data \\
  -e CLICKHOUSE_HOST=${CLICKHOUSE_HOST} \\
  -e CLICKHOUSE_PORT=${CLICKHOUSE_PORT} \\
  -e CLICKHOUSE_DATABASE=${CLICKHOUSE_DB} \\
  -e CLICKHOUSE_USERNAME=${CLICKHOUSE_USER} \\
  -e CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD} \\
  -e MQTT_BROKER_URL=mqtt://${LOCAL_MQTT_HOST}:${LOCAL_MQTT_PORT} \\
  -e MQTT_USERNAME=${LOCAL_MQTT_USER} \\
  -e MQTT_PASSWORD=${LOCAL_MQTT_PASSWORD} \\
  -e MQTT_TOPIC_FILTER=wesense/decoded/# \\
  -e PORT=3000 \\
  -e HOST=0.0.0.0 \\
  -e MAP_CENTER_LAT=${MAP_CENTER_LAT} \\
  -e MAP_CENTER_LNG=${MAP_CENTER_LNG} \\
  -e MAP_ZOOM_LEVEL=${MAP_ZOOM_LEVEL} \\
  -e TZ=${TZ} \\
  ${RESPIRO_IMAGE}
EOF
    echo ""
}

usage() {
    echo "Generate docker run commands for WeSense services"
    echo ""
    echo "Usage: $0 [persona|service]"
    echo ""
    echo "Personas:"
    echo "  contributor - Ingesters only (sends to remote MQTT hub)"
    echo "  station     - Full local stack (EMQX + ClickHouse + Ingesters + Respiro)"
    echo "  hub         - EMQX only (production mqtt.wesense.earth)"
    echo ""
    echo "Services:"
    echo "  emqx                    - MQTT Broker"
    echo "  clickhouse              - Time Series Database"
    echo "  ingester-meshtastic     - Meshtastic Ingester (public + community)"
    echo "  ingester-wesense        - WeSense Ingester (WiFi + LoRa + TTN)"
    echo "  ingester-homeassistant  - Home Assistant Ingester"
    echo "  respiro                 - Environmental Sensor Map"
    echo ""
    echo "Examples:"
    echo "  $0 station               # All commands for station deployment"
    echo "  $0 contributor           # Ingesters only"
    echo "  $0 emqx                  # Just EMQX command"
    echo "  $0 ingester-wesense      # Just WeSense ingester"
    echo "  $0 station > run-all.sh  # Save to script"
    echo ""
    exit 0
}

generate_persona() {
    local persona="$1"
    echo "#!/bin/bash"
    echo "# WeSense ${persona} persona - docker run commands"
    echo "# Generated: $(date)"
    echo ""
    print_network

    case "$persona" in
        hub)
            generate_emqx
            ;;
        contributor)
            generate_ingester_meshtastic
            generate_ingester_wesense
            generate_ingester_homeassistant
            ;;
        station)
            generate_emqx
            generate_clickhouse
            generate_ingester_meshtastic
            generate_ingester_wesense
            generate_ingester_homeassistant
            generate_respiro
            ;;
    esac
}

# Main
case "${1:-}" in
    hub|contributor|station)
        generate_persona "$1"
        ;;
    emqx)
        print_network
        generate_emqx
        ;;
    clickhouse)
        print_network
        generate_clickhouse
        ;;
    ingester-meshtastic)
        print_network
        generate_ingester_meshtastic
        ;;
    ingester-wesense)
        print_network
        generate_ingester_wesense
        ;;
    ingester-homeassistant)
        print_network
        generate_ingester_homeassistant
        ;;
    respiro)
        print_network
        generate_respiro
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        echo -e "${RED}Error: Unknown persona or service: $1${NC}"
        echo ""
        usage
        ;;
esac
