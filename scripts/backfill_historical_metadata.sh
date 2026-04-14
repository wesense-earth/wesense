#!/bin/bash
#
# backfill_historical_metadata.sh
#
# One-off backfill script to populate metadata columns on historical readings
# that predate the ingesters' awareness of those columns.
#
# Run this ONCE on each station after deploying the code that adds columns
# data_license, reading_type_name, and public_key, but BEFORE triggering a
# re-archive. The archive builder will then include the correct metadata
# values in the new Parquet files.
#
# Safe to re-run — each UPDATE is idempotent (only touches rows that still
# have empty/default values).
#
# Usage:
#   ./scripts/backfill_historical_metadata.sh
#
# This runs ALTER TABLE UPDATE mutations which rewrite partitions. On a
# ClickHouse database of a few hundred MB this is fast (seconds). On a
# multi-GB database it can take minutes. ClickHouse runs mutations
# asynchronously — use `SELECT * FROM system.mutations WHERE is_done = 0`
# to check progress.

set -e

CH_EXEC="${CH_EXEC:-docker exec wesense-clickhouse clickhouse-client}"

echo "=== Backfill 1: data_license for govaq-nz historical rows ==="
$CH_EXEC -q "
ALTER TABLE wesense.sensor_readings
UPDATE data_license = 'NZGOAL'
WHERE data_source IN ('ecan', 'tasman', 'nelson', 'marlborough',
                      'hawkesbay', 'gisborne', 'horizons', 'westcoast',
                      'northland')
  AND data_license = 'CC-BY-4.0'
"

echo "=== Backfill 2: reading_type_name from the canonical registry ==="
$CH_EXEC -q "
ALTER TABLE wesense.sensor_readings
UPDATE reading_type_name = multiIf(
    reading_type = 'temperature', 'Temperature',
    reading_type = 'humidity', 'Humidity',
    reading_type = 'pressure', 'Pressure',
    reading_type = 'co2', 'CO₂',
    reading_type = 'pm1_0', 'PM1.0',
    reading_type = 'pm2_5', 'PM2.5',
    reading_type = 'pm10', 'PM10',
    reading_type = 'particles_0_3um', 'Particles (>0.3µm)',
    reading_type = 'particles_0_5um', 'Particles (>0.5µm)',
    reading_type = 'particles_1_0um', 'Particles (>1.0µm)',
    reading_type = 'particles_2_5um', 'Particles (>2.5µm)',
    reading_type = 'particles_5_0um', 'Particles (>5.0µm)',
    reading_type = 'particles_10um', 'Particles (>10µm)',
    reading_type = 'voc_index', 'VOC Index',
    reading_type = 'nox_index', 'NOx Index',
    reading_type = 'voc_raw', 'VOC Raw',
    reading_type = 'nox_raw', 'NOx Raw',
    reading_type = 'light_level', 'Light Level',
    reading_type = 'wind_speed', 'Wind Speed',
    reading_type = 'wind_direction', 'Wind Direction',
    reading_type = 'wind_gust', 'Wind Gust',
    reading_type = 'wind_gust_direction', 'Wind Gust Direction',
    reading_type = 'rainfall', 'Rainfall',
    reading_type = 'no', 'NO',
    reading_type = 'no2', 'NO₂',
    reading_type = 'so2', 'SO₂',
    reading_type = 'o3', 'O₃',
    reading_type = 'co', 'CO',
    ''
)
WHERE reading_type_name = ''
"

echo "=== Backfill 3: public_key from currently-known ingester keys ==="
echo "Reading public keys from data/trust_list.json (local TrustStore)..."

TRUST_FILE="${TRUST_FILE:-data/trust_list.json}"

if [ ! -f "$TRUST_FILE" ]; then
    echo "WARNING: Trust list not found at $TRUST_FILE. Skipping public_key backfill."
    echo "  public_key column will remain empty for historical rows on this station."
    echo "  (New readings will have public_key populated correctly.)"
else
    # Build a CASE WHEN ... from the local trust list.
    # For each (ingester_id, key_version) pair in trust_list.json, emit:
    #   WHEN ingester_id = '...' AND key_version = N THEN '<base64>'
    python3 << 'PYEOF' > /tmp/public_key_cases.sql
import json
import sys

with open("${TRUST_FILE}") as f:
    data = json.load(f)

cases = []
for iid, versions in data.get("keys", {}).items():
    for kv, entry in versions.items():
        pk = entry.get("public_key", "")
        if pk and entry.get("status") == "active":
            cases.append(f"    ingester_id = '{iid}' AND key_version = {int(kv)}, '{pk}'")

if not cases:
    print("-- no active keys in trust list; skipping public_key update")
    sys.exit(0)

sql = "ALTER TABLE wesense.sensor_readings\n"
sql += "UPDATE public_key = multiIf(\n"
sql += ",\n".join(cases) + ",\n"
sql += "    ''\n"
sql += ")\n"
sql += "WHERE public_key = ''"
print(sql)
PYEOF

    if [ -s /tmp/public_key_cases.sql ]; then
        $CH_EXEC --multiquery < /tmp/public_key_cases.sql
    fi
    rm -f /tmp/public_key_cases.sql
fi

echo
echo "=== Backfill complete ==="
echo
echo "ClickHouse runs mutations asynchronously. Check progress with:"
echo "  docker exec wesense-clickhouse clickhouse-client -q \\"
echo "    \"SELECT database, table, mutation_id, is_done, parts_to_do FROM system.mutations WHERE is_done = 0\""
echo
echo "Once all mutations complete, you can trigger the re-archive."
