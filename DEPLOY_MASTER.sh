#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "═══════════════════════════════════════"
echo "    LogLine OS - Master Deployment"
echo "═══════════════════════════════════════"
echo ""

# Step 1: Validate
log_step "Step 1: Validating environment..."
if ./validate_deployment.sh; then
  log_ok "Validation complete"
else
  log_fail "Validation failed"
  exit 1
fi
echo ""

# Step 2: Check if keys need to be generated
if [ ! -f "keys/signing_keys.env" ]; then
  log_step "Step 2: Generating cryptographic keys..."
  ./generate_keys.sh
  log_ok "Keys generated"
else
  log_ok "Keys already exist"
fi
echo ""

# Step 3: Check if DB password needs to be generated
if [ ! -f "keys/db_credentials.env" ]; then
  log_step "Step 3: Generating database password..."
  ./generate_db_password.sh
  log_ok "Database password generated"
else
  log_ok "Database password already exists"
fi
echo ""

# Step 4: Deploy infrastructure
log_step "Step 4: Deploying infrastructure with Terraform..."
cd infra

# Initialize Terraform
terraform init -upgrade

# Plan
log_step "Running terraform plan..."
terraform plan -out=tfplan

# Apply
log_step "Applying Terraform plan..."
read -p "Continue with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  log_fail "Deployment cancelled"
  exit 1
fi

terraform apply tfplan
rm tfplan

log_ok "Infrastructure deployed"
cd ..
echo ""

# Step 5: Wait for database
log_step "Step 5: Waiting for database to be ready..."
sleep 30
log_ok "Database should be ready"
echo ""

# Step 6: Initialize database schema
log_step "Step 6: Initializing database schema..."
cd infra
CONN_STRING=$(terraform output -raw connection_string)
cd ..

if command -v psql &> /dev/null; then
  psql "$CONN_STRING" < infra/scripts/init_db.sql
  log_ok "Schema initialized"
  
  psql "$CONN_STRING" < infra/scripts/seed_manifest.sql
  log_ok "Manifest seeded"
  
  psql "$CONN_STRING" < infra/scripts/seed_kernels.sql
  log_ok "Kernels seeded"
else
  log_fail "psql not found - skipping database initialization"
  echo "   Please install PostgreSQL client and run:"
  echo "   psql \"\$(cd infra && terraform output -raw connection_string)\" < infra/scripts/init_db.sql"
  echo "   psql \"\$(cd infra && terraform output -raw connection_string)\" < infra/scripts/seed_manifest.sql"
  echo "   psql \"\$(cd infra && terraform output -raw connection_string)\" < infra/scripts/seed_kernels.sql"
fi
echo ""

# Step 7: Get endpoints
cd infra
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "not-deployed")
DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "not-deployed")
cd ..

echo ""
echo "═══════════════════════════════════════"
echo "    🎉 DEPLOYMENT COMPLETE! 🎉"
echo "═══════════════════════════════════════"
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
echo "  # Insert span"
echo "  curl -X POST \"$API_ENDPOINT/api/spans\" \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"entity_type\":\"test\",\"who\":\"cli\",\"this\":\"test\"}' | jq ."
echo ""
echo "  # Connect to DB"
echo "  ./connect_db.sh"
echo ""
echo "📊 Monitoring:"
echo "  # View Lambda logs"
echo "  aws logs tail /aws/lambda/logline-dev-stage0 --follow"
echo ""
echo "✅ LogLine OS is LIVE!"
echo ""
