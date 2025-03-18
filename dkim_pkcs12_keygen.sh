# By Thibaut LOMBARD (Lombard Web)
# Mailcow DKIM PKCS12 generator
#!/bin/bash

# Configuration variables
DOMAIN="example.com"        # Replace with your domain
SELECTOR="mailcow"         # DKIM selector (e.g., "mailcow")
KEY_LENGTH=2048         # Key length in bits
OUTPUT_DIR="./dkim_keys"      # Local directory for potential file output

# Debug: Starting key generation
echo "Debug: Generating private key..."
PRIVATE_KEY=$(openssl genrsa "$KEY_LENGTH")

# Debug: Extracting public key
echo "Debug: Extracting public key..."
PUBLIC_KEY=$(openssl rsa -pubout <<< "$PRIVATE_KEY")

# Debug: Formatting DNS record
echo "Debug: Creating DNS TXT record..."
PUB_KEY_DATA=$(echo "$PUBLIC_KEY" | grep -v "-----" | tr -d '\n')
DNS_RECORD="v=DKIM1; k=rsa; p=$PUB_KEY_DATA"

# Echo only the DNS TXT record value
echo "$DNS_RECORD"

# Debug: Generating self-signed certificate for PKCS12
echo "Debug: Generating self-signed certificate for PKCS12..."
CERT=$(openssl req -new -x509 -days 365 -key <(echo "$PRIVATE_KEY") -subj "/CN=$DOMAIN" -nodes)

# Debug: Creating PKCS12 file in memory
echo "Debug: Bundling private key and certificate into PKCS12..."
PKCS12=$(openssl pkcs12 -export -out /dev/null -inkey <(echo "$PRIVATE_KEY") -in <(echo "$CERT") -passout pass:temp 2>/dev/null | base64)

# Prompt to write files
read -p "Debug: Write keys, certificate, PKCS12, and DNS record to $OUTPUT_DIR? (yes/no): " ANSWER

# Handle the response
case "$ANSWER" in
 [Yy]|[Yy][Ee][Ss])
  mkdir -p "$OUTPUT_DIR"
  PRIVKEY_FILE="$OUTPUT_DIR/key.pem"
  PUBKEY_FILE="$OUTPUT_DIR/cert.pem"
  CERT_FILE="$OUTPUT_DIR/selfsigned_cert.pem"
  PKCS12_FILE="$OUTPUT_DIR/${SELECTOR}_dkim.p12"
  DNS_FILE="$OUTPUT_DIR/${SELECTOR}_dns.txt"
  
  # Write files
  echo "$PRIVATE_KEY" > "$PRIVKEY_FILE"
  echo "$PUBLIC_KEY" > "$PUBKEY_FILE"
  echo "$CERT" > "$CERT_FILE"
  echo "$PKCS12" | base64 -d > "$PKCS12_FILE"
  echo "$DNS_RECORD" > "$DNS_FILE"
  
  # Set permissions
  chmod 644 "$PRIVKEY_FILE" "$PUBKEY_FILE" "$CERT_FILE" "$PKCS12_FILE" "$DNS_FILE"
  
  echo "Debug: Files written to:"
  echo "  - Private Key: $PRIVKEY_FILE"
  echo "  - Public Key: $PUBKEY_FILE"
  echo "  - Self-Signed Cert: $CERT_FILE"
  echo "  - PKCS12: $PKCS12_FILE"
  echo "  - DNS TXT Record: $DNS_FILE"
  echo "Note: PKCS12 password is 'temp'."
  ;;
 [Nn]|[Nn][Oo])
  echo "Debug: No files written."
  ;;
 *)
  echo "Debug: Invalid response. No files written."
  ;;
esac
exit 0
