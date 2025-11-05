#!/bin/bash
set -e

echo "🔐 LogLine Key Generation Script"
echo "================================="
echo ""

# Create keys directory
mkdir -p keys

echo "🔑 Generating Ed25519 key pair..."

# Generate private key
openssl genpkey -algorithm ED25519 -out keys/private.pem

# Extract public key
openssl pkey -in keys/private.pem -pubout -out keys/public.pem

# Convert to hex for signing_keys.env
PRIVATE_HEX=$(openssl pkey -in keys/private.pem -text -noout | grep "priv:" -A 3 | tail -n 3 | tr -d ' :\n')
PUBLIC_HEX=$(openssl pkey -in keys/private.pem -text -noout | grep "pub:" -A 2 | tail -n 2 | tr -d ' :\n')

# Create environment file
cat > keys/signing_keys.env << EOF
# Ed25519 Keys for LogLine
# Generated: $(date)
# WARNING: Keep these keys secure! Do not commit to git!

SIGNING_KEY_HEX=$PRIVATE_HEX
PUBLIC_KEY_HEX=$PUBLIC_HEX
EOF

echo "✅ Keys generated successfully!"
echo ""
echo "📂 Files created:"
echo "   keys/private.pem - Private key (PEM format)"
echo "   keys/public.pem - Public key (PEM format)"
echo "   keys/signing_keys.env - Hex-encoded keys for environment variables"
echo ""
echo "⚠️  CRITICAL: Backup keys/private.pem to a secure location!"
echo "   Without it, you cannot sign spans."
echo ""
echo "🔒 The keys/ directory is excluded from git via .gitignore"
