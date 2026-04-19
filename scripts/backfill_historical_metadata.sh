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
    reading_type = 'temperature_5m', 'Temperature (5m)',
    reading_type = 'temperature_6m', 'Temperature (6m)',
    reading_type = 'humidity', 'Humidity',
    reading_type = 'pressure', 'Pressure',
    reading_type = 'co2', 'CO₂',
    reading_type = 'gas_resistance', 'Gas Resistance',
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

echo "=== Backfill 3: public_key from ClickHouse itself ==="
echo "Reading (ingester_id, key_version) → public_key mappings from recent readings..."

# Source the public keys from ClickHouse itself. New readings (from the
# upgraded pipeline) already have public_key populated. Every (ingester_id,
# key_version) pair has exactly one correct public_key value, so we can
# just copy it onto the historical rows that still have empty public_key.
#
# This avoids needing to find trust_list.json on the host, which can live
# in any of several ingester-specific subdirectories.
$CH_EXEC --multiquery <<'SQL'
-- Create a temporary dictionary-like table mapping ingester keys to public_keys,
-- built from the most recent row per (ingester_id, key_version).
CREATE OR REPLACE DICTIONARY wesense.ingester_public_keys (
    ingester_id String,
    key_version UInt32,
    public_key String
)
PRIMARY KEY ingester_id, key_version
SOURCE(CLICKHOUSE(
    QUERY $$
        SELECT
            ingester_id,
            key_version,
            argMax(public_key, timestamp) AS public_key
        FROM wesense.sensor_readings
        WHERE public_key != ''
          AND ingester_id != ''
        GROUP BY ingester_id, key_version
    $$
))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_HASHED());

SYSTEM RELOAD DICTIONARY wesense.ingester_public_keys;

ALTER TABLE wesense.sensor_readings
UPDATE public_key = dictGetOrDefault(
    'wesense.ingester_public_keys',
    'public_key',
    (ingester_id, key_version),
    ''
)
WHERE public_key = ''
  AND ingester_id != '';

DROP DICTIONARY IF EXISTS wesense.ingester_public_keys;
SQL

echo
echo "=== Backfill complete ==="
echo
echo "ClickHouse runs mutations asynchronously. Check progress with:"
echo "  docker exec wesense-clickhouse clickhouse-client -q \\"
echo "    \"SELECT database, table, mutation_id, is_done, parts_to_do FROM system.mutations WHERE is_done = 0\""
echo
echo "Once all mutations complete, you can trigger the re-archive."
