#!/bin/bash
# generate-certs.sh — Generate self-signed TLS certificates for WeSense
#
# Creates a deployment-specific CA (10-year validity) and per-service certificates
# signed by that CA. For LAN-only deployments where Let's Encrypt is not available.
#
# Usage:
#   ./scripts/generate-certs.sh              # Generate CA + all service certs
#   ./scripts/generate-certs.sh --renew      # Re-sign service certs with existing CA
#
# The CA cert (ca.pem) can be flashed to ESP32 devices for MQTTS verification.
# Service certs are used by EMQX, ClickHouse, and other services.
#
# Output directory: ${DATA_DIR}/certs/ (same location EMQX reads from)
#   ca.pem          — CA certificate (distribute to clients / flash to ESP32)
#   ca-key.pem      — CA private key (keep secure, never distribute)
#   fullchain.pem   — Service certificate (used by EMQX, etc.)
#   privkey.pem     — Service private key

set -euo pipefail

# Read DATA_DIR from .env if it exists
if [ -f .env ]; then
    DATA_DIR=$(grep -E '^DATA_DIR=' .env | cut -d= -f2 | tr -d '"' || true)
fi
CERT_DIR="${1:-${DATA_DIR:-./data}/certs}"
CA_DAYS=3650       # 10 years for CA
CERT_DAYS=825      # ~2.25 years for service certs (Apple max)

# Read PUID from .env for cert ownership
PUID="${PUID:-1000}"
if [ -f .env ]; then
    PUID=$(grep -E '^PUID=' .env | cut -d= -f2 | tr -d '"' || echo "1000")
fi

# Service names that appear as SANs in the service cert.
# Includes Docker DNS names, localhost, and common host-gateway addresses
# for services on network_mode: host (archive-replicator, orbitdb).
SANS="DNS:emqx,DNS:clickhouse,DNS:storage-broker,DNS:archive-replicator,DNS:orbitdb,DNS:respiro,DNS:live-transport,DNS:zenoh-api,DNS:localhost,IP:127.0.0.1,IP:172.17.0.1"

mkdir -p "$CERT_DIR"

# Check for --renew flag
RENEW=false
for arg in "$@"; do
    [ "$arg" = "--renew" ] && RENEW=true
done

# Check if CA already exists
if [ -f "$CERT_DIR/ca.pem" ] && [ -f "$CERT_DIR/ca-key.pem" ]; then
    if [ "$RENEW" = true ]; then
        echo "Using existing CA to renew service certificates..."
    else
        echo "CA already exists in $CERT_DIR/"
        echo "  To renew service certs with existing CA: $0 --renew"
        echo "  To regenerate everything: rm $CERT_DIR/ca*.pem and re-run"
        exit 1
    fi
else
    echo "Generating new CA (valid ${CA_DAYS} days / ~10 years)..."
    openssl genrsa -out "$CERT_DIR/ca-key.pem" 4096
    openssl req -new -x509 \
        -key "$CERT_DIR/ca-key.pem" \
        -out "$CERT_DIR/ca.pem" \
        -days "$CA_DAYS" \
        -subj "/O=WeSense/CN=WeSense Deployment CA"

    echo "CA certificate: $CERT_DIR/ca.pem"
    echo "CA private key: $CERT_DIR/ca-key.pem (keep this secure!)"
    echo ""
fi

echo "Generating service certificate (valid ${CERT_DAYS} days)..."

# Generate service key
openssl genrsa -out "$CERT_DIR/privkey.pem" 2048

# Generate CSR with SANs
openssl req -new \
    -key "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/service.csr" \
    -subj "/O=WeSense/CN=wesense-services" \
    -addext "subjectAltName=${SANS}"

# Sign with CA
openssl x509 -req \
    -in "$CERT_DIR/service.csr" \
    -CA "$CERT_DIR/ca.pem" \
    -CAkey "$CERT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CERT_DIR/cert.pem" \
    -days "$CERT_DAYS" \
    -copy_extensions copy

# Create fullchain (service cert + CA cert) — this is what EMQX expects
cat "$CERT_DIR/cert.pem" "$CERT_DIR/ca.pem" > "$CERT_DIR/fullchain.pem"

# Clean up temporary files
rm -f "$CERT_DIR/service.csr" "$CERT_DIR/ca.srl"

echo ""
echo "Certificates generated in $CERT_DIR/:"
echo "  fullchain.pem  — Service cert chain (for EMQX/services)"
echo "  privkey.pem    — Service private key"
echo "  ca.pem         — CA cert (flash to ESP32 devices for MQTTS)"
echo "  ca-key.pem     — CA private key (keep secure!)"
echo ""
echo "To enable internal TLS, set in .env:"
echo "  TLS_ENABLED=true"
echo ""
echo "To renew service certs later (same CA, no ESP32 update needed):"
echo "  $0 --renew"

# Set ownership to PUID so services can read after privilege drop
chown "${PUID}:${PUID}" "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem" "$CERT_DIR/ca.pem" 2>/dev/null || true
chmod 640 "$CERT_DIR/ca-key.pem" "$CERT_DIR/privkey.pem"
chmod 644 "$CERT_DIR/ca.pem" "$CERT_DIR/fullchain.pem" "$CERT_DIR/cert.pem"
