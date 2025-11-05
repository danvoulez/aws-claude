#!/bin/bash
set -e

echo "🚀 LogLine Deployment Script"
echo "============================"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform 1.6+"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI v2"
    exit 1
fi

if ! command -v psql &> /dev/null; then
    echo "⚠️  PostgreSQL client (psql) not found. Database seeding will be skipped."
    echo "   You can install it later and run seed_kernels.sh"
fi

echo "✅ All prerequisites satisfied"
echo ""

# Navigate to infra directory
cd "$(dirname "$0")/infra"

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo "⚠️  terraform.tfvars not found!"
    echo "   Please copy terraform.tfvars.example to terraform.tfvars and fill in your values"
    exit 1
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Deploy all modules
echo ""
echo "🚀 Deploying all modules..."
echo "   This will deploy: Database, Secrets, Stage-0, Kernels, API, Scheduler"
echo "   Estimated time: 15-20 minutes"
echo ""
terraform apply

# Check if deployment was successful
if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

# Get database connection string
echo ""
echo "📊 Getting deployment outputs..."
CONN_STRING=$(terraform output -raw connection_string 2>/dev/null || echo "")
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")

# Initialize schema if psql is available
if command -v psql &> /dev/null && [ -n "$CONN_STRING" ]; then
    echo ""
    echo "📊 Initializing database schema..."
    
    # Wait a bit for database to be fully ready
    echo "⏳ Waiting for database to be fully ready (30 seconds)..."
    sleep 30
    
    # Initialize schema
    if psql "$CONN_STRING" < scripts/init_db.sql 2>/dev/null; then
        echo "✅ Schema initialized"
    else
        echo "⚠️  Schema initialization failed (database may not be ready yet)"
        echo "   You can run it manually later:"
        echo "   psql \"\$(terraform output -raw connection_string)\" < scripts/init_db.sql"
    fi
    
    # Seed manifest
    echo "📦 Seeding manifest..."
    if psql "$CONN_STRING" < scripts/seed_manifest.sql 2>/dev/null; then
        echo "✅ Manifest seeded"
    else
        echo "⚠️  Manifest seeding failed"
    fi
    
    # Seed kernels
    echo "🔌 Seeding kernel functions..."
    if psql "$CONN_STRING" < scripts/seed_kernels.sql 2>/dev/null; then
        echo "✅ Kernels seeded"
    else
        echo "⚠️  Kernel seeding failed"
    fi
else
    echo ""
    echo "⚠️  Skipping database initialization (psql not available or database not ready)"
    echo "   Run ./seed_kernels.sh later to initialize the database"
fi

echo ""
echo "✅ Deployment Complete!"
echo "======================="
echo ""
echo "📍 Your Endpoints:"
echo "   API:      $API_ENDPOINT"
echo "   Database: $DB_ENDPOINT"
echo ""
echo "🧪 Quick Tests:"
echo ""
echo "  # Query timeline"
echo "  curl \"$API_ENDPOINT/api/timeline?limit=5\" | jq ."
echo ""
echo "  # Insert test span"
echo "  curl -X POST \"$API_ENDPOINT/api/spans\" \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"entity_type\":\"test\",\"who\":\"cli\",\"this\":\"test\"}' | jq ."
echo ""
echo "  # Connect to database"
echo "  ../connect_db.sh"
echo ""
echo "  # View logs"
echo "  ../tail_logs.sh stage0"
echo ""
echo "📝 Next Steps:"
echo "   - Run tests: ../test_deployment.sh"
echo "   - View logs: ../tail_logs.sh <function_name>"
echo "   - Seed kernels (if skipped): ../seed_kernels.sh"
echo ""

