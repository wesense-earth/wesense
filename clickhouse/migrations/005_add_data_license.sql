-- Migration 005: Add data_license column for per-reading license tracking

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS data_license LowCardinality(String) DEFAULT 'CC-BY-4.0';
