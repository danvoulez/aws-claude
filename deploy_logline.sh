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
    echo "❌ PostgreSQL client (psql) not found. Please install PostgreSQL 16+"
    exit 1
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

# Deploy Database Module
echo ""
echo "🗄️  Deploying Database Module..."
echo "   This will take 5-10 minutes for RDS provisioning..."
terraform apply -target=module.database -auto-approve

# Wait for RDS to be available
echo ""
echo "⏳ Waiting for RDS to become available..."
DB_IDENTIFIER=$(terraform output -raw database_endpoint | cut -d: -f1)
aws rds wait db-instance-available --db-instance-identifier "${DB_IDENTIFIER%-*}"

# Get database connection string
echo ""
echo "📊 Initializing database schema..."
CONN_STRING=$(terraform output -raw connection_string)

# Initialize schema
psql "$CONN_STRING" < scripts/init_db.sql

# Seed manifest
echo "📦 Seeding manifest..."
psql "$CONN_STRING" < scripts/seed_manifest.sql

# Seed kernels
echo "🔌 Seeding kernel functions..."
psql "$CONN_STRING" < scripts/seed_kernels.sql

echo ""
echo "✅ Deployment Complete!"
echo "======================="
echo ""
echo "📍 Database Endpoint:"
terraform output database_endpoint
echo ""
echo "🧪 Test Connection:"
echo "   psql '$(terraform output -raw connection_string)'"
echo ""
echo "📝 Next Steps:"
echo "   1. Deploy Stage-0 Lambda module"
echo "   2. Deploy API Gateway module"
echo "   3. Deploy Kernels module"
echo "   4. Deploy Scheduler module"
echo ""
echo "See PLAN.MD for detailed instructions."
