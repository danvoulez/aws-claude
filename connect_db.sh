#!/bin/bash
set -e

echo "🔌 LogLine Database Connection Script"
echo "====================================="
echo ""

cd "$(dirname "$0")/infra"

if [ ! -f terraform.tfvars ]; then
    echo "❌ terraform.tfvars not found. Please run deploy_logline.sh first."
    exit 1
fi

# Check if database is deployed
if ! terraform output database_endpoint &> /dev/null; then
    echo "❌ Database not deployed yet. Please run deploy_logline.sh first."
    exit 1
fi

CONN_STRING=$(terraform output -raw connection_string)

echo "📊 Connecting to LogLine database..."
echo ""

psql "$CONN_STRING"
