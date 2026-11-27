-- Migration 011: latest reading per sensor and reading type
--
-- "Latest reading for every sensor" (the map, the dashboard, the device list)
-- used to scan sensor_readings: all of it, or a time window of it, on every
-- request. sensor_latest holds one row per (device_id, reading_type), kept
-- current by ClickHouse on every insert into sensor_readings, so those reads
-- touch a few rows per sensor whatever the length of history.
--
-- Every write path inserts (storage broker, live transport from P2P, any future
-- archive import), so every reading reaches this table. Nothing modifies
-- sensor_readings rows in place any more (migration 010 moved the deployment
-- classifier to its own table), so it cannot drift from sensor_readings.
--
-- reading_count is readings received: the backfill counts stored rows once,
-- and afterwards every insert adds to it, so a re-sent duplicate counts twice.
--
-- Local and derived: never archived, never replicated. Each station builds its
-- own from what it has received. Rows expire with the same 3-year rule as
-- sensor_readings, so a sensor whose readings have all expired drops out too.

CREATE TABLE IF NOT EXISTS wesense.sensor_latest
(
    `device_id` String,
    `reading_type` LowCardinality(String),
    `latest_timestamp` SimpleAggregateFunction(max, DateTime64(3, 'UTC')),
    `reading_count` SimpleAggregateFunction(sum, UInt64),
    `value` AggregateFunction(argMax, Float64, DateTime64(3, 'UTC')),
    `reading_type_name` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `unit` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `latitude` AggregateFunction(argMax, Float64, DateTime64(3, 'UTC')),
    `longitude` AggregateFunction(argMax, Float64, DateTime64(3, 'UTC')),
    `geo_country` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `geo_subdivision` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `node_name` AggregateFunction(argMax, Nullable(String), DateTime64(3, 'UTC')),
    `board_model` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `data_source` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `data_source_name` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `sensor_model` AggregateFunction(argMax, LowCardinality(String), DateTime64(3, 'UTC')),
    `deployment_location` AggregateFunction(argMax, Nullable(String), DateTime64(3, 'UTC')),
    `node_info` AggregateFunction(argMax, Nullable(String), DateTime64(3, 'UTC')),
    `node_info_url` AggregateFunction(argMax, Nullable(String), DateTime64(3, 'UTC'))
)
ENGINE = AggregatingMergeTree
ORDER BY (device_id, reading_type)
TTL toDateTime(latest_timestamp) + toIntervalYear(3);

CREATE MATERIALIZED VIEW IF NOT EXISTS wesense.sensor_latest_mv
TO wesense.sensor_latest
AS SELECT
    device_id,
    reading_type,
    max(timestamp) AS latest_timestamp,
    count() AS reading_count,
    argMaxState(value, timestamp) AS value,
    argMaxState(reading_type_name, timestamp) AS reading_type_name,
    argMaxState(unit, timestamp) AS unit,
    argMaxState(latitude, timestamp) AS latitude,
    argMaxState(longitude, timestamp) AS longitude,
    argMaxState(geo_country, timestamp) AS geo_country,
    argMaxState(geo_subdivision, timestamp) AS geo_subdivision,
    argMaxState(node_name, timestamp) AS node_name,
    argMaxState(board_model, timestamp) AS board_model,
    argMaxState(data_source, timestamp) AS data_source,
    argMaxState(data_source_name, timestamp) AS data_source_name,
    argMaxState(sensor_model, timestamp) AS sensor_model,
    argMaxState(deployment_location, timestamp) AS deployment_location,
    argMaxState(node_info, timestamp) AS node_info,
    argMaxState(node_info_url, timestamp) AS node_info_url
FROM wesense.sensor_readings
GROUP BY device_id, reading_type;

-- One-off backfill from existing readings, after the view exists so no insert is
-- missed. reading_count counts each stored row once: FINAL collapses rows that
-- sensor_readings has not merged yet (re-sent duplicates).
INSERT INTO wesense.sensor_latest
SELECT
    device_id,
    reading_type,
    max(timestamp) AS latest_timestamp,
    count() AS reading_count,
    argMaxState(value, timestamp) AS value,
    argMaxState(reading_type_name, timestamp) AS reading_type_name,
    argMaxState(unit, timestamp) AS unit,
    argMaxState(latitude, timestamp) AS latitude,
    argMaxState(longitude, timestamp) AS longitude,
    argMaxState(geo_country, timestamp) AS geo_country,
    argMaxState(geo_subdivision, timestamp) AS geo_subdivision,
    argMaxState(node_name, timestamp) AS node_name,
    argMaxState(board_model, timestamp) AS board_model,
    argMaxState(data_source, timestamp) AS data_source,
    argMaxState(data_source_name, timestamp) AS data_source_name,
    argMaxState(sensor_model, timestamp) AS sensor_model,
    argMaxState(deployment_location, timestamp) AS deployment_location,
    argMaxState(node_info, timestamp) AS node_info,
    argMaxState(node_info_url, timestamp) AS node_info_url
FROM wesense.sensor_readings FINAL
GROUP BY device_id, reading_type;
