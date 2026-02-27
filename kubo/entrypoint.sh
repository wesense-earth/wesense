#!/bin/sh
# Wrapper entrypoint for Kubo that runs BEFORE the user switch to ipfs.
#
# Removes stale repo.lock left behind by unclean shutdowns (server reboot,
# OOM kill, etc). The lock file can end up owned by root, which prevents
# the ipfs user from acquiring it on restart — causing a crash loop.
#
# Safe to remove unconditionally: if this script is running, no daemon is
# active, so any existing lock is guaranteed stale.

rm -f /data/ipfs/repo.lock 2>/dev/null || true

exec /usr/local/bin/start_ipfs "$@"
