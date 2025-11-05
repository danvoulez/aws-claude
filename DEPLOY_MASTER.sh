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
./validate_deployment.sh
log_ok "Validation complete"
echo ""

# Step 2: Generate keys if missing
if [ ! -f "keys/signing_keys.env" ]; then
  log_step "Step 2: Generating cryptographic keys..."
  ./generate_keys.sh
  log_ok "Keys generated"
else
  log_ok "Cryptographic keys already exist"
fi
echo ""

# Step 3: Generate DB password if missing
if [ ! -f "keys/db_credentials.env" ]; then
  log_step "Step 3: Generating database password..."
  ./generate_db_password.sh
  log_ok "Database password generated"
else
  log_ok "Database password already exists"
fi
echo ""

# Step 4: Generate tfvars if missing
if [ ! -f "infra/terraform.tfvars" ]; then
  log_step "Step 4: Generating terraform.tfvars..."
  # For automated deployment, create a basic tfvars
  # In production, users should customize this
  cat > infra/terraform.tfvars <<EOF
aws_region  = "us-east-1"
environment = "dev"

db_name     = "logline"
db_username = "logline_admin"
db_password = "$(grep DB_PASSWORD keys/db_credentials.env | cut -d= -f2)"

db_instance_class     = "db.t4g.micro"
db_allocated_storage  = 20
db_multi_az          = false

db_backup_retention_period = 7
db_backup_window          = "03:00-04:00"
db_maintenance_window     = "mon:04:00-mon:05:00"

db_allowed_cidr_blocks = []
EOF
  log_ok "terraform.tfvars generated"
else
  log_ok "terraform.tfvars already exists"
fi
echo ""

# Step 5: Deploy
log_step "Step 5: Deploying infrastructure..."
./deploy_logline.sh
log_ok "Infrastructure deployed"
echo ""

# Step 6: Check if deployment was successful before seeding
cd infra
if terraform output -raw database_endpoint &> /dev/null; then
  API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "Not yet deployed")
  DB_ENDPOINT=$(terraform output -raw database_endpoint)
  cd ..
  
  log_step "Step 6: Seeding kernel functions..."
  # Kernel seeding would happen here if we have the seed_kernels.sh script
  if [ -f "./seed_kernels.sh" ]; then
    ./seed_kernels.sh
    log_ok "Kernels seeded"
  else
    log_ok "Kernel seeding skipped (script not found)"
  fi
  echo ""
  
  # Step 7: Run tests if available
  if [ -f "./test_deployment.sh" ]; then
    log_step "Step 7: Running tests..."
    ./test_deployment.sh
    log_ok "Tests complete"
  else
    log_ok "Tests skipped (script not found)"
  fi
  echo ""
  
  echo ""
  echo "═══════════════════════════════════════"
  echo "    🎉 DEPLOYMENT COMPLETE! 🎉"
  echo "═══════════════════════════════════════"
  echo ""
  echo "📍 Your Endpoints:"
  echo "   API:      ${API_ENDPOINT}"
  echo "   Database: ${DB_ENDPOINT}"
  echo ""
  echo "🧪 Quick Tests:"
  echo ""
  if [ "$API_ENDPOINT" != "Not yet deployed" ]; then
    echo "  # Query timeline"
    echo "  curl \"${API_ENDPOINT}/api/timeline?limit=5\" | jq ."
    echo ""
    echo "  # Insert span"
    echo "  curl -X POST \"${API_ENDPOINT}/api/spans\" \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"entity_type\":\"test\",\"who\":\"cli\",\"this\":\"test\"}' | jq ."
    echo ""
  fi
  echo "  # Connect to DB"
  echo "  ./connect_db.sh"
  echo ""
  echo "✅ LogLine OS is LIVE!"
  echo ""
else
  cd ..
  log_fail "Deployment may have failed - check Terraform output"
  exit 1
fi
