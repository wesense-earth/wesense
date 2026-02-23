#!/bin/sh
# Kubo first-run configuration for WeSense IPFS archives.
# Placed in /container-init.d/ — runs after `ipfs init` but before the daemon starts.
# See: https://docs.ipfs.tech/how-to/run-ipfs-inside-docker/#running-ipfs-inside-docker

set -e

# Bind the API to all interfaces so other Docker containers can reach it.
# The API port (5001) is NOT published to the host — only accessible within
# the Docker network (wesense-net). The swarm port (4001) IS published.
ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001

# Enable the DHT in server mode when publicly reachable (ANNOUNCE_ADDRESS set),
# otherwise use auto mode (promotes to server if publicly reachable).
if [ -n "$ANNOUNCE_ADDRESS" ]; then
  ipfs config Routing.Type dhtserver

  # Check if it's an IP or hostname
  case "$ANNOUNCE_ADDRESS" in
    *[a-zA-Z]*)
      # Hostname — use /dns4/
      ipfs config --json Addresses.Announce "[\"//dns4/$ANNOUNCE_ADDRESS/tcp/4001\", \"/dns4/$ANNOUNCE_ADDRESS/udp/4001/quic-v1\"]"
      ;;
    *)
      # IPv4 address
      ipfs config --json Addresses.Announce "[\"/ip4/$ANNOUNCE_ADDRESS/tcp/4001\", \"/ip4/$ANNOUNCE_ADDRESS/udp/4001/quic-v1\"]"
      ;;
  esac

  echo "Kubo: Configured DHT server mode with announce address $ANNOUNCE_ADDRESS"
else
  ipfs config Routing.Type dhtclient
  echo "Kubo: Configured DHT client mode (no ANNOUNCE_ADDRESS)"
fi

# Disable the gateway — we don't need to serve HTTP content from this node.
# Archives are accessed via public IPFS gateways (dweb.link etc).
ipfs config Addresses.Gateway ""

echo "Kubo: Init complete"
