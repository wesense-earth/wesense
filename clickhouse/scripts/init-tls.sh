#!/bin/bash
# init-tls.sh — Conditionally enable ClickHouse HTTPS
# Runs before ClickHouse starts. Writes TLS config only when TLS_ENABLED=true
# and cert files exist.

CERT_DIR="/etc/clickhouse-server/certs"
CONFIG_DIR="/etc/clickhouse-server/config.d"

if [ "${TLS_ENABLED}" = "true" ] && [ -f "${CERT_DIR}/fullchain.pem" ] && [ -f "${CERT_DIR}/privkey.pem" ]; then
    mkdir -p "${CONFIG_DIR}"
    cat > "${CONFIG_DIR}/tls.xml" << 'EOF'
<clickhouse>
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
    echo "ClickHouse TLS enabled (HTTPS on 8443)"
else
    # Remove TLS config if it exists from a previous run
    rm -f "${CONFIG_DIR}/tls.xml"
fi

# Hand off to the real ClickHouse entrypoint
exec /entrypoint.sh "$@"
