#!/bin/sh
# Wrapper entrypoint for Kubo that runs on EVERY container start.
#
# 1. Removes stale repo.lock from unclean shutdowns
# 2. Applies configuration if repo already exists (ensures config changes
#    from configure.sh take effect without wiping the data directory)
# 3. Hands off to start_ipfs (which handles first-run init + daemon start)
#
# On first run: repo doesn't exist yet → skip config here, start_ipfs will
# call ipfs init then run /container-init.d/init.sh which applies config.
#
# On subsequent runs: repo exists → apply config here, start_ipfs skips
# init and container-init.d, goes straight to daemon.

# Remove stale repo.lock left behind by unclean shutdowns (server reboot,
# OOM kill, etc). Safe to remove unconditionally: if this script is running,
# no daemon is active, so any existing lock is guaranteed stale.
rm -f /data/ipfs/repo.lock 2>/dev/null || true

# Apply configuration if repo already exists.
# On first run the config file won't exist yet — that's fine,
# container-init.d/init.sh will handle it after ipfs init.
if [ -f /data/ipfs/config ]; then
  echo "Kubo: Existing repo found, applying configuration..."
  . /configure-kubo.sh
  # Restore ownership — ipfs config runs as root but the daemon
  # runs as the ipfs user and needs to read its own config.
  chown ipfs:ipfs /data/ipfs/config
fi

exec /usr/local/bin/start_ipfs "$@"
