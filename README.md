# WeSense

The main deployment repository for the WeSense environmental sensor platform. Clone this repo to run WeSense.

## Overview

WeSense orchestrates upstream images and custom services:

| Service | Image | Description |
|---------|-------|-------------|
| EMQX | `emqx/emqx:5.8.9` | MQTT broker |
| ClickHouse | `clickhouse/clickhouse-server:24` | Time-series database |
| Ingester Meshtastic | `ghcr.io/wesense-earth/wesense-ingester-meshtastic` | Decodes Meshtastic mesh traffic |
| Ingester WeSense | `ghcr.io/wesense-earth/wesense-ingester-wesense` | Decodes WiFi/LoRa sensors |
| Ingester Home Assistant | `ghcr.io/wesense-earth/wesense-ingester-homeassistant` | Pulls data from Home Assistant |
| Respiro | `ghcr.io/wesense-earth/wesense-respiro` | Sensor map web UI |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/wesense-earth/wesense
cd wesense

# 2. Configure
cp .env.sample .env
# Edit .env — change all CHANGEME passwords before starting

# 3. Start
docker compose --profile station up -d

# 4. Access
# Respiro Map: http://localhost:3000
# EMQX Dashboard: http://localhost:18083 (admin / your EMQX_DASHBOARD_PASSWORD)
```

## Deployment Profiles

Set `COMPOSE_PROFILES` in `.env` or use `--profile` on the command line.

| Profile | Services | Use Case |
|---------|----------|----------|
| `station` | EMQX, ClickHouse, Ingesters, Respiro | Full local stack |
| `contributor` | Ingesters only | Contribute sensor data to a remote hub |
| `hub` | EMQX only | Production MQTT broker |
| `observer` | ClickHouse, Respiro | Map + live data (future) |

See [Deployment_Personas.md](https://github.com/wesense-earth/wesense-general-docs/blob/main/general/Deployment_Personas.md) for full details.

## Directory Structure

```
wesense/
├── docker-compose.yml          # Service orchestration
├── .env.sample                 # Configuration template
├── emqx/etc/emqx.conf          # EMQX broker configuration
├── clickhouse/init/            # ClickHouse schema init scripts
├── certs/                      # TLS certificates (gitignored)
├── ingester-meshtastic/        # Volume mounts (cache, config, logs)
├── ingester-homeassistant/     # Volume mounts (config)
└── respiro/                    # Volume mounts (data cache)
```

## Configuration

See `.env.sample` for all available options:

- Port mappings
- TLS configuration
- ClickHouse credentials
- MQTT settings
- Map defaults

## Security Notes

1. **Change all CHANGEME passwords** in `.env` before starting — the config-check service will block startup if you don't
2. **ClickHouse uses two accounts**: `default` (admin, internal only) and `wesense` (restricted app user for ingesters/Respiro). The `wesense` user is created automatically on first start
3. **MQTT authentication is opt-in**: set `MQTT_USER` + `MQTT_PASSWORD` in `.env` to enable it. Leave both empty for anonymous access (fine for local networks)
4. **EMQX dashboard password**: set `EMQX_DASHBOARD_PASSWORD` in `.env` (login as `admin`)
5. **Change the EMQX Erlang cookie** in `emqx/etc/emqx.conf` for multi-node deployments
6. **Enable TLS** for production (`TLS_MQTT_ENABLED=true`)

## Migrating Existing Deployments

If you're upgrading from an older version that used `CLICKHOUSE_USER=default` for everything:

1. Add the new variables to your `.env`:
   ```
   CLICKHOUSE_ADMIN_PASSWORD=<your-existing-clickhouse-password>
   EMQX_DASHBOARD_PASSWORD=<choose-a-password>
   ```

2. Create the restricted ClickHouse app user manually (the init script only runs on first start):
   ```bash
   docker exec wesense-clickhouse clickhouse-client --query "
     CREATE USER IF NOT EXISTS wesense IDENTIFIED BY '<your-app-password>';
     GRANT SELECT, INSERT ON wesense.* TO wesense;
     GRANT SELECT, INSERT ON wesense_respiro.* TO wesense;
   "
   ```

3. Update your `.env`:
   ```
   CLICKHOUSE_USER=wesense
   CLICKHOUSE_PASSWORD=<your-app-password>
   ```

4. Restart the stack: `docker compose --profile station up -d`

## Related Repositories

| Repository | Description |
|------------|-------------|
| [wesense-respiro](https://github.com/wesense-earth/wesense-respiro) | Sensor map source code |
| [wesense-ingester-meshtastic](https://github.com/wesense-earth/wesense-ingester-meshtastic) | Meshtastic ingester source |
| [wesense-ingester-core](https://github.com/wesense-earth/wesense-ingester-core) | Shared ingester library |
| [wesense-general-docs](https://github.com/wesense-earth/wesense-general-docs) | Architecture documentation |

## License

MIT License
