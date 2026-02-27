#!/bin/sh
# Kubo configuration for WeSense IPFS archives.
#
# Single source of truth for all Kubo settings. Called from:
#   - entrypoint.sh (every start — applies config to existing repos)
#   - init.sh (first run via container-init.d — applies config after ipfs init)
#
# All commands here are idempotent — safe to run repeatedly.

set -e

# Bind the API to all interfaces so other Docker containers can reach it.
# The API port (5001) is NOT published to the host — only accessible within
# the Docker network (wesense-net). The swarm port (4001) IS published.
ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001

# Enable the Accelerated DHT Client for faster provider record publishing
# and DHT lookups. This maintains a full routing table in the background
# and parallelises DHT queries, dramatically improving content discoverability
# by public IPFS gateways (dweb.link, ipfs.io, etc.).
ipfs config --json Routing.AcceleratedDHTClient true

# Configure the provider to announce content frequently. Default is 22h
# which means a newly archived file might not be discoverable for up to 22h.
# "all" strategy re-announces all pinned + MFS content (not just roots).
# Kubo 0.40.0 renamed Reprovider → Provide (FATAL if old keys remain).
ipfs config --json Provide.Strategy '"all"'
ipfs config --json Provide.DHT.Interval '"12h"'

# Remove deprecated Reprovider section from config (fatal in Kubo 0.40.0+).
# ipfs config can't delete keys, so edit the JSON file directly with awk.
CONFIG="${IPFS_PATH:-/data/ipfs}/config"
if grep -q '"Reprovider"' "$CONFIG" 2>/dev/null; then
  echo "Kubo: Removing deprecated Reprovider config..."
  awk '/"Reprovider"[[:space:]]*:/{skip=1;next} skip && /^  \}/{skip=0;next} skip{next} {print}' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
fi

# Enable the DHT in server mode when publicly reachable (ANNOUNCE_ADDRESS set),
# otherwise fall back to client mode.
if [ -n "$ANNOUNCE_ADDRESS" ]; then
  ipfs config Routing.Type dhtserver

  # Check if it's an IP or hostname
  case "$ANNOUNCE_ADDRESS" in
    *[a-zA-Z]*)
      # Hostname — use /dns4/
      ipfs config --json Addresses.Announce "[\"/dns4/$ANNOUNCE_ADDRESS/tcp/4001\", \"/dns4/$ANNOUNCE_ADDRESS/udp/4001/quic-v1\"]"
      ;;
    *)
      # IPv4 address
      ipfs config --json Addresses.Announce "[\"/ip4/$ANNOUNCE_ADDRESS/tcp/4001\", \"/ip4/$ANNOUNCE_ADDRESS/udp/4001/quic-v1\"]"
      ;;
  esac

  echo "Kubo: Configured DHT server mode with announce address $ANNOUNCE_ADDRESS"
else
  ipfs config Routing.Type dhtclient
  echo "Kubo: WARNING — no ANNOUNCE_ADDRESS set, DHT client mode only."
  echo "Kubo: Archives will NOT be discoverable by public IPFS gateways."
  echo "Kubo: Set ANNOUNCE_ADDRESS in .env to your public IP or hostname."
fi

# Disable the gateway — we don't need to serve HTTP content from this node.
# Archives are accessed via public IPFS gateways (dweb.link etc).
ipfs config Addresses.Gateway ""

echo "Kubo: Configuration applied"
