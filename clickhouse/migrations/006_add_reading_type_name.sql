-- Migration 006: Add reading_type_name column for human-readable display names

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS reading_type_name LowCardinality(String) DEFAULT '';
