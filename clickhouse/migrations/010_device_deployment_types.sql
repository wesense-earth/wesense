-- Migration 010: deployment types without rewriting or scanning sensor_readings
--
-- Before this, the deployment classifier stored each decision by rewriting the
-- device's rows in sensor_readings (ALTER TABLE ... UPDATE). Each one rewrote
-- large parts of the table, ran hundreds of times per classifier cycle, and
-- broke the readings' signatures. Readers then worked out each device's type by
-- scanning all of sensor_readings on every request.
--
-- Now:
--   device_classifications   the classifier's decisions (one row per decision;
--                             the latest per device wins)
--   device_reported_types     each device's latest non-empty type as its ingester
--                             reported (and signed) it, kept current on insert
--   device_deployment_types   view combining the two, which every reader uses
--
-- All three are local to the station and derived: nothing here is archived or
-- replicated. Classifications reach other stations through the classifier's own
-- snapshot exchange, as before.

CREATE TABLE IF NOT EXISTS wesense.device_classifications
(
    `device_id` String,
    `deployment_type` LowCardinality(String),      -- '' = cleared (UNKNOWN), eligible for reclassification
    `deployment_type_source` LowCardinality(String), -- 'classifier' or 'remote'
    `overrides` UInt8,                             -- 1: wins over the device's own reported type
    `node_name` String,                            -- from a remote classification; used only when the device reports none
    `latitude` Nullable(Float64),
    `longitude` Nullable(Float64),
    `classified_at` DateTime64(3, 'UTC')
)
ENGINE = ReplacingMergeTree(classified_at)
ORDER BY device_id;

CREATE TABLE IF NOT EXISTS wesense.device_reported_types
(
    `device_id` String,
    `type_state` AggregateFunction(argMaxIf, LowCardinality(String), DateTime64(3, 'UTC'), UInt8),
    `source_state` AggregateFunction(argMaxIf, LowCardinality(String), DateTime64(3, 'UTC'), UInt8)
)
ENGINE = AggregatingMergeTree
ORDER BY device_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS wesense.device_reported_types_mv
TO wesense.device_reported_types
AS SELECT
    device_id,
    argMaxIfState(deployment_type, timestamp, deployment_type != '') AS type_state,
    argMaxIfState(deployment_type_source, timestamp, deployment_type != '') AS source_state
FROM wesense.sensor_readings
GROUP BY device_id;

-- One-off backfill from existing readings. Safe to repeat: argMax states merge.
INSERT INTO wesense.device_reported_types (device_id, type_state, source_state)
SELECT
    device_id,
    argMaxIfState(deployment_type, timestamp, deployment_type != '') AS type_state,
    argMaxIfState(deployment_type_source, timestamp, deployment_type != '') AS source_state
FROM wesense.sensor_readings
GROUP BY device_id;

-- Effective type per device. Precedence, as the classifier applied it before:
-- an overriding classification, then the device's own reported type, then the
-- classifier's suggestion for a device that reports none.
CREATE OR REPLACE VIEW wesense.device_deployment_types AS
SELECT
    device_id,
    multiIf(c_overrides = 1 AND c_type != '', c_type, r_type != '', r_type, c_type) AS deployment_type,
    multiIf(c_overrides = 1 AND c_type != '', c_source, r_type != '', r_source, c_type != '', c_source, '') AS deployment_type_source,
    c_node_name AS classified_node_name,
    c_latitude AS classified_latitude,
    c_longitude AS classified_longitude
FROM
(
    SELECT
        device_id,
        argMaxIfMerge(type_state) AS r_type,
        argMaxIfMerge(source_state) AS r_source
    FROM wesense.device_reported_types
    GROUP BY device_id
) AS r
FULL OUTER JOIN
(
    SELECT
        device_id,
        argMax(deployment_type, classified_at) AS c_type,
        argMax(deployment_type_source, classified_at) AS c_source,
        argMax(overrides, classified_at) AS c_overrides,
        argMax(node_name, classified_at) AS c_node_name,
        argMax(latitude, classified_at) AS c_latitude,
        argMax(longitude, classified_at) AS c_longitude
    FROM wesense.device_classifications
    GROUP BY device_id
) AS c USING (device_id)
SETTINGS join_use_nulls = 0;
