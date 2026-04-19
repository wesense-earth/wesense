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
# migrate.sh applies numbered SQL files from /migrations/, tracking
# applied versions in wesense.schema_migrations. All migrations are
# idempotent so safe on both fresh installs and existing deployments.
(
    /scripts/migrate.sh

    # Ensure app user can read system.parts (needed for storage stats in Respiro)
    for i in $(seq 1 60); do
        if clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
            if [ -n "$CLICKHOUSE_APP_USER" ] && [ "$CLICKHOUSE_APP_USER" != "default" ]; then
                clickhouse-client --query "GRANT SELECT ON system.parts TO \`${CLICKHOUSE_APP_USER}\`" 2>/dev/null && \
                    echo "Permissions: system.parts grant ensured for ${CLICKHOUSE_APP_USER}" || true
            fi
            break
        fi
        sleep 2
    done
) &

# Hand off to the real ClickHouse entrypoint
exec /entrypoint.sh "$@"
