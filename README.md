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
# Edit .env with your settings (at minimum, set CLICKHOUSE_PASSWORD)

# 3. Start
docker compose --profile station up -d

# 4. Access
# Respiro Map: http://localhost:3000
# EMQX Dashboard: http://localhost:18083 (admin/public)
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

1. **Set a strong ClickHouse password** in `.env`
2. **Change the EMQX dashboard password** on first login (default: admin/public)
3. **Change the EMQX Erlang cookie** in `emqx/etc/emqx.conf` for multi-node deployments
4. **Enable TLS** for production (`TLS_MQTT_ENABLED=true`)

## Related Repositories

| Repository | Description |
|------------|-------------|
| [wesense-respiro](https://github.com/wesense-earth/wesense-respiro) | Sensor map source code |
| [wesense-ingester-meshtastic](https://github.com/wesense-earth/wesense-ingester-meshtastic) | Meshtastic ingester source |
| [wesense-ingester-core](https://github.com/wesense-earth/wesense-ingester-core) | Shared ingester library |
| [wesense-general-docs](https://github.com/wesense-earth/wesense-general-docs) | Architecture documentation |

## License

MIT License
