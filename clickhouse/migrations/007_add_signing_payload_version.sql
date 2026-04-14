-- Migration 007: Add signing_payload_version for long-term signature verification

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS signing_payload_version UInt16 DEFAULT 1;
