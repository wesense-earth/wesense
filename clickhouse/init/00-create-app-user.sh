#!/bin/bash
# 00-create-app-user.sh — Create a restricted application user for ingesters/Respiro
#
# Runs on first ClickHouse startup (empty data dir) as the 'default' admin user.
# Creates the user specified by CLICKHOUSE_APP_USER with CLICKHOUSE_APP_PASSWORD,
# then grants SELECT + INSERT on the wesense and wesense_respiro databases.
#
# Skips if CLICKHOUSE_APP_USER is empty or 'default' (no separate user needed).
set -e

if [ -z "$CLICKHOUSE_APP_USER" ] || [ "$CLICKHOUSE_APP_USER" = "default" ]; then
    echo "00-create-app-user: No separate app user requested, skipping."
    exit 0
fi

if [ -z "$CLICKHOUSE_APP_PASSWORD" ]; then
    echo "00-create-app-user: ERROR — CLICKHOUSE_APP_PASSWORD is empty" >&2
    exit 1
fi

echo "00-create-app-user: Creating user '$CLICKHOUSE_APP_USER' with restricted access..."

clickhouse-client --query "
    CREATE USER IF NOT EXISTS \`${CLICKHOUSE_APP_USER}\`
        IDENTIFIED BY '${CLICKHOUSE_APP_PASSWORD}';

    GRANT SELECT, INSERT ON wesense.* TO \`${CLICKHOUSE_APP_USER}\`;
    GRANT SELECT, INSERT ON wesense_respiro.* TO \`${CLICKHOUSE_APP_USER}\`;
"

echo "00-create-app-user: User '$CLICKHOUSE_APP_USER' created with SELECT/INSERT on wesense and wesense_respiro."
