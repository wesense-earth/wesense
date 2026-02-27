#!/bin/sh
# First-run configuration — called from /container-init.d/ after `ipfs init`.
# Delegates to configure.sh (single source of truth for all Kubo settings).
# See: https://docs.ipfs.tech/how-to/run-ipfs-inside-docker/#running-ipfs-inside-docker

. /configure-kubo.sh
