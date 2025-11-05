#!/bin/bash
set -e

echo "🔐 LogLine Database Password Generator"
echo "======================================"
echo ""

# Create keys directory
mkdir -p keys

echo "🔑 Generating secure database password..."

# Generate a 32-character secure password
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Create environment file
cat > keys/db_credentials.env << EOF
# Database Credentials for LogLine
# Generated: $(date)
# WARNING: Keep this file secure! Do not commit to git!

DB_PASSWORD=$DB_PASSWORD
EOF

echo "✅ Database password generated successfully!"
echo ""
echo "📂 File created:"
echo "   keys/db_credentials.env"
echo ""
echo "📝 Next steps:"
echo "   1. Copy this password to infra/terraform.tfvars"
echo "   2. Set: db_password = \"$DB_PASSWORD\""
echo ""
echo "🔒 The keys/ directory is excluded from git via .gitignore"
