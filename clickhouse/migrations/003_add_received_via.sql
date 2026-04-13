-- Migration 003: Add received_via column for local vs P2P provenance tracking

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS received_via LowCardinality(String) DEFAULT 'local';
