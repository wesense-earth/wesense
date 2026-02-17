#!/bin/sh
set -e

ARGS="--config /zenoh.json5"

if [ -n "$ZENOH_PROXY_ROUTER" ]; then
    echo "Zenoh proxy mode: forwarding to upstream router $ZENOH_PROXY_ROUTER"
    ARGS="$ARGS --connect $ZENOH_PROXY_ROUTER"
fi

exec zenohd $ARGS
