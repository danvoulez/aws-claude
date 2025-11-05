#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }

echo ""
echo "═══════════════════════════════════════"
echo "    LogLine OS - Master Deployment"
echo "═══════════════════════════════════════"
echo ""

START_TIME=$(date +%s)

# Step 1: Validate
log_step "Step 1/6: Validating environment..."
if ./validate_deployment.sh; then
  log_ok "Validation complete"
else
  log_fail "Validation failed"
  exit 1
fi
echo ""

# Step 2: Generate credentials if missing
log_step "Step 2/6: Checking credentials..."

if [ ! -f "keys/signing_keys.env" ]; then
  log_info "Generating signing keys..."
  ./generate_keys.sh
  log_ok "Signing keys generated"
else
  log_ok "Signing keys already exist"
fi

if [ ! -f "keys/db_credentials.env" ]; then
  log_info "Generating database password..."
  ./generate_db_password.sh
  log_ok "Database password generated"
else
  log_ok "Database password already exists"
fi
echo ""

# Step 3: Install Node.js dependencies
log_step "Step 3/6: Installing dependencies..."

if [ ! -d "src/stage0/node_modules" ]; then
  log_info "Installing Stage-0 dependencies..."
  cd src/stage0
  npm install --production --silent
  cd ../..
  log_ok "Stage-0 dependencies installed"
else
  log_ok "Stage-0 dependencies already installed"
fi

if [ ! -d "src/kernels/node_modules" ]; then
  log_info "Installing kernel dependencies..."
  cd src/kernels
  npm install --production --silent
  cd ../..
  log_ok "Kernel dependencies installed"
else
  log_ok "Kernel dependencies already installed"
fi
echo ""

# Step 4: Prepare Terraform
log_step "Step 4/6: Preparing Terraform..."

if [ ! -f "infra/terraform.tfvars" ]; then
  log_info "Creating terraform.tfvars from example..."
  cp infra/terraform.tfvars.example infra/terraform.tfvars
  
  # Try to populate with generated credentials
  if [ -f "keys/db_credentials.env" ]; then
    source keys/db_credentials.env
    if [ -n "$DB_PASSWORD" ]; then
      # Update the tfvars with the password
      # Note: In production, consider using environment variables or
      # Terraform's -var-file option to avoid storing credentials in files
      sed -i.bak "s|db_password.*=.*|db_password = \"$DB_PASSWORD\"|" infra/terraform.tfvars
      rm infra/terraform.tfvars.bak 2>/dev/null || true
    fi
  fi
  
  if [ -f "keys/signing_keys.env" ]; then
    source keys/signing_keys.env
    if [ -n "$SIGNING_KEY_HEX" ]; then
      # Update the tfvars with the signing key
      # Note: In production, consider using environment variables or
      # Terraform's -var-file option to avoid storing credentials in files
      sed -i.bak "s|signing_key_hex.*=.*|signing_key_hex = \"$SIGNING_KEY_HEX\"|" infra/terraform.tfvars
      rm infra/terraform.tfvars.bak 2>/dev/null || true
    fi
  fi
  
  log_ok "terraform.tfvars created and populated"
  log_info "Please review and edit infra/terraform.tfvars if needed"
  echo ""
  read -p "Press Enter to continue or Ctrl+C to exit..."
else
  log_ok "terraform.tfvars already exists"
fi
echo ""

# Step 5: Deploy infrastructure
log_step "Step 5/6: Deploying infrastructure with Terraform..."

cd infra

if [ ! -d ".terraform" ]; then
  log_info "Initializing Terraform..."
  terraform init
  log_ok "Terraform initialized"
fi

log_info "Planning deployment..."
terraform plan -out=tfplan

log_info "Applying Terraform configuration..."
echo ""
read -p "Proceed with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  log_fail "Deployment cancelled by user"
  exit 1
fi

terraform apply tfplan
rm tfplan 2>/dev/null || true

log_ok "Infrastructure deployed"

# Get outputs
DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")

cd ..
echo ""

# Step 6: Initialize database
log_step "Step 6/6: Initializing database..."

if [ -n "$DB_ENDPOINT" ]; then
  log_info "Running init_db.sql..."
  ./deploy_logline.sh
  log_ok "Database schema initialized"
  
  log_info "Seeding kernel functions..."
  ./seed_kernels.sh
  log_ok "Kernel functions seeded"
else
  log_fail "Could not get database endpoint"
  exit 1
fi
echo ""

# Calculate deployment time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "═══════════════════════════════════════"
echo "    🎉 DEPLOYMENT COMPLETE! 🎉"
echo "═══════════════════════════════════════"
echo ""
echo "⏱️  Deployment time: ${MINUTES}m ${SECONDS}s"
echo ""

# Show endpoints
if [ -n "$API_ENDPOINT" ]; then
  echo "📍 Your Endpoints:"
  echo "   API:      $API_ENDPOINT"
  echo "   Database: $DB_ENDPOINT"
  echo ""
fi

echo "🧪 Quick Tests:"
echo ""

if [ -n "$API_ENDPOINT" ]; then
  echo "  # Query timeline"
  echo "  curl \"$API_ENDPOINT/api/timeline?limit=5\" | jq ."
  echo ""
  echo "  # Insert test span"
  echo "  curl -X POST \"$API_ENDPOINT/api/spans\" \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"entity_type\":\"test\",\"who\":\"cli\",\"this\":\"test\"}' | jq ."
  echo ""
fi

echo "  # Connect to database"
echo "  ./connect_db.sh"
echo ""
echo "  # Run automated tests"
echo "  ./test_deployment.sh"
echo ""

echo "📊 Next Steps:"
echo ""
echo "  1. Run tests to verify deployment:"
echo "     ./test_deployment.sh"
echo ""
echo "  2. View CloudWatch logs:"
echo "     aws logs tail /aws/lambda/logline-dev-stage0 --follow"
echo ""
echo "  3. Monitor the timeline:"
echo "     watch -n 5 'curl -s \"$API_ENDPOINT/api/timeline?limit=10\" | jq .'"
echo ""

echo "✅ LogLine OS is LIVE!"
echo ""
