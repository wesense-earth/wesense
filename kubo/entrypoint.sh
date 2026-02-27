#!/bin/sh
# Wrapper entrypoint for Kubo that runs on EVERY container start.
#
# 1. Adjusts ipfs user UID/GID to match PUID/PGID from environment
# 2. Ensures correct ownership of the data directory
# 3. Removes stale repo.lock from unclean shutdowns
# 4. Applies configuration if repo already exists
# 5. Hands off to start_ipfs (first-run init + container-init.d + daemon)

set -e

# ── Match ipfs user to host PUID/PGID ──
# Same pattern as EMQX: bind-mounted data dirs need correct host ownership.
# Defaults to UID/GID 1000 (the ipfs user's built-in values).
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

CURRENT_UID=$(id -u ipfs)
CURRENT_GID=$(id -g ipfs)

if [ "$PUID" != "$CURRENT_UID" ] || [ "$PGID" != "$CURRENT_GID" ]; then
  echo "Kubo: Adjusting ipfs user UID:GID from ${CURRENT_UID}:${CURRENT_GID} to ${PUID}:${PGID}"
  sed -i "s/^ipfs:x:${CURRENT_UID}:${CURRENT_GID}:/ipfs:x:${PUID}:${PGID}:/" /etc/passwd
fi

# ── Fix data directory ownership ──
# The official start_ipfs only checks top-level writability before skipping
# chown -R. If subdirectory files have wrong ownership (e.g., created by root
# via Docker bind-mount auto-creation, or left by a previous UID), ipfs
# commands fail with "permission denied".
if [ -d /data/ipfs ]; then
  OWNER=$(stat -c '%u' /data/ipfs)
  if [ "$OWNER" != "$PUID" ]; then
    echo "Kubo: Fixing data directory ownership (${OWNER} → ${PUID}:${PGID})..."
    chown -R "${PUID}:${PGID}" /data/ipfs
  fi
fi

# ── Remove stale repo.lock ──
rm -f /data/ipfs/repo.lock 2>/dev/null || true

# ── Apply configuration if repo already exists ──
# On first run the config file won't exist yet — start_ipfs will call
# ipfs init then run /container-init.d/001-configure.sh.
if [ -f /data/ipfs/config ]; then
  echo "Kubo: Existing repo found, applying configuration..."
  su-exec ipfs sh /configure-kubo.sh
fi

exec /usr/local/bin/start_ipfs "$@"
