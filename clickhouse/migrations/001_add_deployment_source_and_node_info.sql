-- Migration 001: Add deployment_type_source, node_info, and node_info_url columns

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS deployment_type_source LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS node_info Nullable(String);

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS node_info_url Nullable(String);
