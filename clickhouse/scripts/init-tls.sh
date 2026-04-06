#!/bin/bash
# init-tls.sh — Conditionally enable ClickHouse HTTPS
# Runs before ClickHouse starts. Writes TLS config only when TLS_ENABLED=true
# and cert files exist.

CERT_DIR="/etc/clickhouse-server/certs"
CONFIG_DIR="/etc/clickhouse-server/config.d"

if [ "${TLS_ENABLED}" = "true" ] && [ -f "${CERT_DIR}/fullchain.pem" ] && [ -f "${CERT_DIR}/privkey-clickhouse.pem" ]; then
    mkdir -p "${CONFIG_DIR}"
    cat > "${CONFIG_DIR}/tls.xml" << 'EOF'
<clickhouse>
    <!-- HTTPS replaces HTTP when TLS_ENABLED=true -->
    <http_port remove="remove"/>
    <https_port>8443</https_port>
    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/certs/fullchain.pem</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/certs/privkey-clickhouse.pem</privateKeyFile>
            <caConfig>/etc/clickhouse-server/certs/ca.pem</caConfig>
            <verificationMode>none</verificationMode>
            <loadDefaultCAFile>false</loadDefaultCAFile>
            <cacheSessions>true</cacheSessions>
        </server>
    </openSSL>
</clickhouse>
EOF
    echo "ClickHouse TLS enabled (HTTPS on 8443, HTTP disabled)"
else
    # Remove TLS config if it exists from a previous run
    rm -f "${CONFIG_DIR}/tls.xml"
fi

# Run schema migrations in background after ClickHouse starts.
# These are idempotent ALTER TABLE ADD COLUMN IF NOT EXISTS statements
# that ensure existing deployments get new columns added since their
# initial setup. New deployments already have all columns from 01-create-tables.sql.
(
    # Wait for ClickHouse to be ready
    for i in $(seq 1 60); do
        if clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
            clickhouse-client --query "ALTER TABLE wesense.sensor_readings ADD COLUMN IF NOT EXISTS data_source_name LowCardinality(String) DEFAULT ''" 2>/dev/null && \
                echo "Schema migration: data_source_name column ensured" || true
            break
        fi
        sleep 2
    done
) &

# Hand off to the real ClickHouse entrypoint
exec /entrypoint.sh "$@"
