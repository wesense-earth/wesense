-- Migration 004: Add data_source_name column and fix defaults from 'unknown' to ''

ALTER TABLE wesense.sensor_readings
  ADD COLUMN IF NOT EXISTS `data_source_name` LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
  MODIFY COLUMN `calibration_status` LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
  MODIFY COLUMN `transport_type` LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
  MODIFY COLUMN `deployment_type` LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
  MODIFY COLUMN `location_source` LowCardinality(String) DEFAULT '';

ALTER TABLE wesense.sensor_readings
  MODIFY COLUMN `deployment_type_source` LowCardinality(String) DEFAULT '';
