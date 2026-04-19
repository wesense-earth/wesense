-- Migration 002: Add Ed25519 signature columns for P2P verification

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS signature String DEFAULT '';

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS ingester_id LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS key_version UInt32 DEFAULT 0;
