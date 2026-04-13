#!/bin/bash
# migrate.sh — Apply pending ClickHouse schema migrations
#
# Called from init-tls.sh in background after ClickHouse starts.
# Scans /migrations/*.sql for numbered migration files, skips any
# already recorded in wesense.schema_migrations, applies the rest
# in order.
#
# All migrations MUST be idempotent (ADD COLUMN IF NOT EXISTS, etc.)
# as a safety net, but the version tracking means they only run once
# under normal circumstances.

set -e

MIGRATIONS_DIR="/migrations"
CH_CLIENT="clickhouse-client"

# ── Wait for ClickHouse to accept queries ───────────────────────
echo "migrate.sh: Waiting for ClickHouse..."
for i in $(seq 1 60); do
    if $CH_CLIENT --query "SELECT 1" > /dev/null 2>&1; then
        echo "migrate.sh: ClickHouse is ready"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "migrate.sh: ERROR — ClickHouse not ready after 120s, aborting" >&2
        exit 1
    fi
    sleep 2
done

# ── Create tracking table (idempotent) ─────────────────────────
$CH_CLIENT --multiquery <<'SQL'
CREATE TABLE IF NOT EXISTS wesense.schema_migrations (
    version String,
    name String,
    applied_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree()
ORDER BY version
SQL

# ── Apply unapplied migrations in order ────────────────────────
applied=0
skipped=0

for f in $(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort); do
    filename=$(basename "$f")
    version=$(echo "$filename" | cut -d_ -f1)
    name=$(basename "$f" .sql)

    # Check if already applied
    count=$($CH_CLIENT --query "SELECT count() FROM wesense.schema_migrations FINAL WHERE version = '$version'" 2>/dev/null)
    if [ "$count" != "0" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    echo "migrate.sh: Applying $name..."
    if $CH_CLIENT --multiquery < "$f"; then
        $CH_CLIENT --query "INSERT INTO wesense.schema_migrations (version, name) VALUES ('$version', '$name')"
        echo "migrate.sh: Applied $name"
        applied=$((applied + 1))
    else
        echo "migrate.sh: FAILED to apply $name" >&2
        exit 1
    fi
done

if [ "$applied" -eq 0 ] && [ "$skipped" -gt 0 ]; then
    echo "migrate.sh: Schema up to date ($skipped migrations already applied)"
elif [ "$applied" -gt 0 ]; then
    echo "migrate.sh: Applied $applied migration(s), $skipped already applied"
else
    echo "migrate.sh: No migrations found in $MIGRATIONS_DIR"
fi
