-- Migration 008: Add public_key column
--
-- Stores the Ed25519 public key (base64, 32 raw bytes → 44 chars) that was
-- used to sign this reading. Per-row storage (via LowCardinality dictionary
-- encoding) so archives can be built without dependence on a live trust store.
-- See governance-and-trust.md for the full retention model.

ALTER TABLE wesense.sensor_readings
    ADD COLUMN IF NOT EXISTS public_key LowCardinality(String) DEFAULT '';
