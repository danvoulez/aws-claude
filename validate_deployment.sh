#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "🔍 LogLine Validation"
echo "===================="
echo ""

# 1. Check files exist
echo "📁 Checking project structure..."
REQUIRED_FILES=(
  "infra/terraform.tfvars.example"
  "infra/main.tf"
  "infra/variables.tf"
  "infra/outputs.tf"
  "src/stage0/index.js"
  "src/stage0/db.js"
  "src/stage0/package.json"
  "src/kernels/db.js"
  "src/kernels/package.json"
  "src/kernels/run_code/index.js"
  "src/kernels/observer_bot/index.js"
  "src/kernels/request_worker/index.js"
  "src/kernels/policy_agent/index.js"
  "src/kernels/provider_exec/index.js"
  "infra/modules/database/main.tf"
  "infra/modules/secrets/main.tf"
  "infra/modules/secrets/iam.tf"
  "infra/modules/stage0/main.tf"
  "infra/modules/kernels/main.tf"
  "infra/modules/api/main.tf"
  "infra/modules/scheduler/main.tf"
  "infra/scripts/init_db.sql"
  "infra/scripts/seed_manifest.sql"
  "infra/scripts/seed_kernels.sql"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$file" ]; then
    log_ok "$file"
  else
    log_fail "$file MISSING"
    exit 1
  fi
done

# 2. Check AWS credentials
echo ""
echo "🔐 Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
  ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
  REGION=$(aws configure get region)
  log_ok "AWS authenticated (Account: $ACCOUNT, Region: $REGION)"
else
  log_fail "AWS not configured"
  exit 1
fi

# 3. Check Terraform
echo ""
echo "🔧 Checking Terraform..."
cd infra
if terraform validate &> /dev/null; then
  log_ok "Terraform configuration valid"
else
  log_fail "Terraform validation failed"
  terraform validate
  exit 1
fi
cd ..

# 4. Check database credentials (if they exist)
echo ""
echo "🔑 Checking credentials..."
if [ -f "keys/db_credentials.env" ]; then
  source keys/db_credentials.env
  if [ -z "$DB_PASSWORD" ]; then
    log_fail "DB_PASSWORD not set"
    exit 1
  else
    log_ok "DB_PASSWORD set (${#DB_PASSWORD} chars)"
  fi
else
  log_warn "keys/db_credentials.env not found (will be generated)"
fi

if [ -f "keys/signing_keys.env" ]; then
  source keys/signing_keys.env
  if [ -z "$SIGNING_KEY_HEX" ]; then
    log_fail "SIGNING_KEY_HEX not set"
    exit 1
  else
    log_ok "SIGNING_KEY_HEX set (${#SIGNING_KEY_HEX} chars)"
  fi

  if [ -z "$PUBLIC_KEY_HEX" ]; then
    log_fail "PUBLIC_KEY_HEX not set"
    exit 1
  else
    log_ok "PUBLIC_KEY_HEX set (${#PUBLIC_KEY_HEX} chars)"
  fi
else
  log_warn "keys/signing_keys.env not found (will be generated)"
fi

# 5. Check Node.js dependencies
echo ""
echo "📦 Checking Node.js dependencies..."
if [ -d "src/stage0/node_modules" ]; then
  log_ok "Stage-0 dependencies installed"
else
  log_warn "Stage-0 dependencies not installed, installing..."
  cd src/stage0 && npm install --production && cd ../..
  log_ok "Stage-0 dependencies installed"
fi

if [ -d "src/kernels/node_modules" ]; then
  log_ok "Kernel dependencies installed"
else
  log_warn "Kernel dependencies not installed, installing..."
  cd src/kernels && npm install --production && cd ../..
  log_ok "Kernel dependencies installed"
fi

# 6. Check SQL files
echo ""
echo "📝 Checking SQL files..."
if grep -q "ledger.universal_registry" infra/scripts/init_db.sql; then
  log_ok "init_db.sql looks valid"
else
  log_fail "init_db.sql missing universal_registry"
  exit 1
fi

if grep -q "kernel_manifest" infra/scripts/seed_manifest.sql; then
  log_ok "seed_manifest.sql looks valid"
else
  log_fail "seed_manifest.sql missing kernel_manifest"
  exit 1
fi

echo ""
log_ok "All validation checks passed!"
echo ""
echo "✅ Ready to deploy!"
echo ""
echo "Next steps:"
echo "  1. ./generate_keys.sh              # Generate cryptographic keys (if not done)"
echo "  2. ./generate_db_password.sh       # Generate DB password (if not done)"
echo "  3. ./deploy_logline.sh             # Deploy infrastructure"
echo "  4. ./infra/scripts/seed_kernels.sh # Seed kernel functions (after deployment)"
echo ""
