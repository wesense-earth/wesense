-- Migration 009: store altitude as Float64
--
-- altitude is a signed (canonical) field and ingesters sign it as a 64-bit
-- float. Stored as Float32, a value like 12.3 came back as 12.300000190734863,
-- so the rebuilt payload no longer matched the signature and the reading could
-- not be archived. Existing values keep the precision they were stored with;
-- this stops new readings losing it.

ALTER TABLE wesense.sensor_readings
    MODIFY COLUMN altitude Nullable(Float64);
