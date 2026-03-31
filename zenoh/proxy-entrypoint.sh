#!/bin/sh
set -e

ARGS="--config /zenoh.json5"

if [ -n "$WESENSE_PROXY" ]; then
    ZENOH_PORT="${PORT_ZENOH:-7447}"
    echo "Zenoh proxy mode: forwarding to upstream router tcp/${WESENSE_PROXY}:${ZENOH_PORT}"
    ARGS="$ARGS --connect tcp/${WESENSE_PROXY}:${ZENOH_PORT}"
fi

exec /zenohd $ARGS
