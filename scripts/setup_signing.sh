#!/bin/bash
# scripts/setup_signing.sh — Checks or creates a self-signed code-signing identity "PersonaMode Dev".
set -eu

CERT_NAME="PersonaMode Dev"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "Code-signing identity '$CERT_NAME' is already installed."
    exit 0
fi

echo "=== Setting up '$CERT_NAME' Self-Signed Code Signing Identity ==="
TMP_CERT_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_CERT_DIR"' EXIT

cat > "$TMP_CERT_DIR/cert.conf" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_dn
x509_extensions    = codesign_ext
prompt             = no

[ req_dn ]
CN = $CERT_NAME
O  = Persona Mode Dev

[ codesign_ext ]
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:FALSE
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP_CERT_DIR/key.pem" \
    -out "$TMP_CERT_DIR/cert.pem" \
    -days 3650 \
    -config "$TMP_CERT_DIR/cert.conf" >/dev/null 2>&1

echo "Generated self-signed certificate at $TMP_CERT_DIR/cert.pem."
echo "To trust it for macOS TCC persistence without interactive keychain prompts:"
echo "  1. Open Keychain Access -> Certificate Assistant -> Create a Certificate..."
echo "  2. Name: '$CERT_NAME', Identity Type: Self Signed Root, Certificate Type: Code Signing"
echo "  3. Re-run 'make app' to sign with '$CERT_NAME'."

