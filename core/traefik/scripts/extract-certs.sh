#!/bin/bash
#
# Extract certificates from acme.json and create individual cert files
# Usage: ./extract-certs.sh [domain]
#

ACME_FILE="../traefik-data/acme.json"
CERTS_DIR="../traefik-data/certs"
DOMAIN="${1:-}"

# Create certs directory if it doesn't exist
mkdir -p "$CERTS_DIR"
chmod 700 "$CERTS_DIR"

# Function to extract certificate for a specific domain
extract_cert() {
    local domain="$1"
    echo "Extracting certificate for $domain..."

    # Extract certificate
    jq -r ".letsencrypt.Certificates[] | select(.domain.main == \"$domain\") | .certificate" "$ACME_FILE" | \
        base64 -d > "$CERTS_DIR/$domain.crt"

    # Extract private key
    jq -r ".letsencrypt.Certificates[] | select(.domain.main == \"$domain\") | .key" "$ACME_FILE" | \
        base64 -d > "$CERTS_DIR/$domain.key"

    # Set proper permissions
    chmod 644 "$CERTS_DIR/$domain.crt"
    chmod 600 "$CERTS_DIR/$domain.key"

    echo "✅ Extracted $domain.crt and $domain.key"
}

# If domain specified, extract only that domain
if [ -n "$DOMAIN" ]; then
    extract_cert "$DOMAIN"
    exit 0
fi

# Otherwise, extract all domains
echo "Extracting all certificates from acme.json..."
domains=$(jq -r '.letsencrypt.Certificates[].domain.main' "$ACME_FILE")

for domain in $domains; do
    extract_cert "$domain"
done

echo ""
echo "Certificate extraction complete!"
echo "Certificates saved to: $CERTS_DIR"
echo ""
echo "Next steps:"
echo "1. Create dynamic/tls-certs.yml configuration"
echo "2. Restart Traefik to load certificates"
