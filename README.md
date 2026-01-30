# WeSense Deploy

Deployment orchestration for the WeSense platform. This repository contains Docker Compose configurations, init scripts, and tooling to deploy the full WeSense stack.

## Overview

This is a **deployment repository**, not application code. It orchestrates upstream images and custom WeSense services:

| Service | Image | Type |
|---------|-------|------|
| EMQX | `emqx/emqx:5` | Upstream |
| ClickHouse | `clickhouse/clickhouse-server:24` | Upstream |
| Ingester Meshtastic | `ghcr.io/wesense-earth/wesense-ingester-meshtastic` | WeSense |
| Ingester WeSense | `ghcr.io/wesense-earth/wesense-ingester-wesense` | WeSense |
| Ingester Home Assistant | `ghcr.io/wesense-earth/wesense-ingester-homeassistant` | WeSense |
| Respiro | `ghcr.io/wesense-earth/wesense-respiro` | WeSense |

## Quick Start

```bash
# 1. Clone and configure
cp .env.sample .env
# Edit .env with your settings

# 2. Start services
docker compose --profile station up -d

# 3. Access services
# EMQX Dashboard: http://localhost:18083 (admin/public)
# Respiro Map: http://localhost:3000
# ClickHouse: http://localhost:8123
```

## Deployment Personas

Set `COMPOSE_PROFILES` in `.env` or use `--profile` directly. See [Deployment_Personas.md](../wesense-general-docs/general/Deployment_Personas.md) for full details.

| Profile | Services | Use Case |
|---------|----------|----------|
| `contributor` | Ingesters | Contribute sensor data to remote hub |
| `station` | EMQX, ClickHouse, Ingesters, Respiro | Full local stack |
| `hub` | EMQX | Production MQTT broker |
| `observer` | ClickHouse, Respiro | Map + live data (future, needs P2P) |

## Unraid Compatibility

Unraid doesn't support docker-compose. Generate equivalent `docker run` commands:

```bash
./scripts/docker-run.sh station > run-all.sh
chmod +x run-all.sh
./run-all.sh
```

Or generate for individual services:

```bash
./scripts/docker-run.sh emqx
./scripts/docker-run.sh clickhouse
```

## Directory Structure

```
wesense-deploy/
├── docker-compose.yml          # Service orchestration
├── scripts/docker-run.sh       # Unraid compatibility
├── .env.sample                 # Configuration template
├── emqx/etc/emqx.conf          # EMQX broker configuration
├── clickhouse/init/            # ClickHouse schema init scripts
├── certs/                      # TLS certificates (gitignored)
├── ingester-meshtastic/        # Volume mounts (cache, config, logs)
├── ingester-homeassistant/     # Volume mounts (config)
└── respiro/                    # Volume mounts (data)
```

## Related Repositories

| Repository | Description |
|------------|-------------|
| [wesense-ingester-meshtastic](https://github.com/wesense-earth/wesense-ingester-meshtastic) | Meshtastic data ingester |
| [wesense-respiro](https://github.com/wesense-earth/wesense-respiro) | Environmental sensor map |
| [wesense-general-docs](https://github.com/wesense-earth/wesense-general-docs) | Architecture documentation |

## Configuration

See `.env.sample` for all available options including:

- Port mappings
- TLS configuration
- ClickHouse credentials
- MQTT settings
- Map defaults

## Security Notes

1. **Change the EMQX Erlang cookie** in `emqx/etc/emqx.conf` before deploying
2. **Change the dashboard password** on first login (default: admin/public)
3. **Enable TLS** for production (`TLS_MQTT_ENABLED=true`)
4. **Set a strong password** for ClickHouse

## Version Pinning

Upstream images use major version tags to receive security updates while avoiding breaking changes:

- `emqx:5` - Gets 5.x updates, won't jump to 6.x
- `clickhouse:24` - Gets 24.x updates, won't jump to 25.x
- `postgres:16-alpine` - Gets 16.x updates

## License

MIT License
