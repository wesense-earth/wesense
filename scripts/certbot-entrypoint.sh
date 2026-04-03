#!/bin/sh
# certbot-entrypoint.sh — Obtain and auto-renew Let's Encrypt certs for EMQX
#
# Runs as a Docker container alongside EMQX. On first start, obtains certs
# via DNS-01 challenge (no port 80/443 needed). Then renews every 12 hours
# and copies fresh certs to the shared volume EMQX reads from.
#
# Required env vars:
#   TLS_DOMAIN          — Domain to get cert for (e.g. mqtt.wesense.earth)
#   CLOUDFLARE_API_TOKEN — Cloudflare API token with Zone:DNS:Edit
#
# Optional:
#   CERTBOT_EMAIL       — Email for Let's Encrypt notifications (recommended)
#   CERTBOT_STAGING     — Set to "true" to use LE staging (for testing)

set -e

CERT_DIR="/etc/letsencrypt/live/${TLS_DOMAIN}"
OUTPUT_DIR="/certs/mqtt"

if [ -z "$TLS_DOMAIN" ]; then
    echo "ERROR: TLS_DOMAIN not set"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "ERROR: CLOUDFLARE_API_TOKEN not set"
    exit 1
fi

# Write Cloudflare credentials
mkdir -p /etc/letsencrypt
cat > /etc/cloudflare.ini << EOF
dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}
EOF
chmod 600 /etc/cloudflare.ini

# Build certbot args
CERTBOT_ARGS="certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare.ini -d ${TLS_DOMAIN} --key-type rsa --non-interactive --agree-tos"

if [ -n "$CERTBOT_EMAIL" ]; then
    CERTBOT_ARGS="$CERTBOT_ARGS --email ${CERTBOT_EMAIL}"
else
    CERTBOT_ARGS="$CERTBOT_ARGS --register-unsafely-without-email"
fi

if [ "$CERTBOT_STAGING" = "true" ]; then
    CERTBOT_ARGS="$CERTBOT_ARGS --staging"
    echo "Using Let's Encrypt STAGING environment (certs won't be trusted)"
fi

# Obtain cert if we don't have one, or re-obtain if the existing cert
# uses the wrong key type (e.g. ECDSA instead of RSA).
NEED_CERT=false
if [ ! -f "${CERT_DIR}/fullchain.pem" ]; then
    echo "No certificate found for ${TLS_DOMAIN}"
    NEED_CERT=true
elif ! openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -text 2>/dev/null | grep -q "rsaEncryption"; then
    echo "Existing certificate uses non-RSA key type — re-obtaining as RSA..."
    CERTBOT_ARGS="$CERTBOT_ARGS --force-renewal --cert-name ${TLS_DOMAIN}"
    NEED_CERT=true
else
    echo "Certificate already exists for ${TLS_DOMAIN} (RSA, valid)"
fi

if [ "$NEED_CERT" = true ]; then
    echo "Obtaining certificate for ${TLS_DOMAIN}..."
    if ! certbot $CERTBOT_ARGS; then
        echo "ERROR: certbot failed. Will retry at next renewal check."
    fi
fi

# Copy certs to shared volume (EMQX reads from here)
copy_certs() {
    if [ -f "${CERT_DIR}/fullchain.pem" ] && [ -f "${CERT_DIR}/privkey.pem" ]; then
        mkdir -p "${OUTPUT_DIR}"
        cp -L "${CERT_DIR}/fullchain.pem" "${OUTPUT_DIR}/fullchain.pem"
        cp -L "${CERT_DIR}/privkey.pem" "${OUTPUT_DIR}/privkey.pem"
        # Public cert is world-readable, private key is owner+group only.
        # Ownership set to EMQX's runtime user so it can read after privilege drop.
        chown "${CERT_OWNER:-1000}:${CERT_OWNER:-1000}" "${OUTPUT_DIR}/fullchain.pem" "${OUTPUT_DIR}/privkey.pem"
        chmod 644 "${OUTPUT_DIR}/fullchain.pem"
        chmod 640 "${OUTPUT_DIR}/privkey.pem"
        echo "Certs copied to ${OUTPUT_DIR}/ (owner=${CERT_OWNER:-1000})"

        # Reload EMQX if it's running (may fail on first start, that's OK)
        if command -v docker >/dev/null 2>&1; then
            docker exec wesense-emqx emqx ctl listeners restart 2>/dev/null && \
                echo "EMQX listeners reloaded" || true
        fi
    fi
}

copy_certs

echo "Starting renewal loop (checking every 12 hours)..."
while true; do
    sleep 43200  # 12 hours
    echo "Checking for renewal..."
    certbot renew --quiet --deploy-hook "echo 'Renewed, copying certs...'"
    copy_certs
done
