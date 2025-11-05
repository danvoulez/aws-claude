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
  "src/stage0/index.js"
  "src/stage0/db.js"
  "src/stage0/package.json"
  "src/kernels/db.js"
  "src/kernels/run_code/index.js"
  "src/kernels/observer_bot/index.js"
  "src/kernels/request_worker/index.js"
  "src/kernels/policy_agent/index.js"
  "src/kernels/provider_exec/index.js"
  "infra/modules/database/main.tf"
  "infra/modules/secrets/main.tf"
  "infra/modules/stage0/main.tf"
  "infra/modules/kernels/main.tf"
  "infra/modules/api/main.tf"
  "infra/modules/scheduler/main.tf"
  "infra/scripts/init_db.sql"
  "infra/scripts/seed_manifest.sql"
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
  REGION=$(aws configure get region || echo "not set")
  log_ok "AWS authenticated (Account: $ACCOUNT, Region: $REGION)"
else
  log_fail "AWS not configured"
  echo "Please run: aws configure"
  exit 1
fi

# 3. Check Terraform
echo ""
echo "🔧 Checking Terraform..."
if ! command -v terraform &> /dev/null; then
  log_fail "Terraform not installed"
  echo "Please install Terraform: https://www.terraform.io/downloads"
  exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
log_ok "Terraform installed (version $TERRAFORM_VERSION)"

cd infra
terraform fmt -check &> /dev/null || log_warn "Terraform files need formatting (run: terraform fmt)"

if terraform validate &> /dev/null; then
  log_ok "Terraform configuration valid"
else
  log_fail "Terraform validation failed"
  terraform validate
  exit 1
fi
cd ..

# 4. Check for credentials files (optional)
echo ""
echo "🔑 Checking credentials..."
if [ -f "keys/db_credentials.env" ]; then
  log_ok "keys/db_credentials.env exists"
  source keys/db_credentials.env
  
  if [ -z "$DB_PASSWORD" ]; then
    log_warn "DB_PASSWORD not set in keys/db_credentials.env"
  else
    log_ok "DB_PASSWORD set (${#DB_PASSWORD} chars)"
  fi
else
  log_warn "keys/db_credentials.env not found (run: ./generate_db_password.sh)"
fi

if [ -f "keys/signing_keys.env" ]; then
  log_ok "keys/signing_keys.env exists"
  source keys/signing_keys.env
  
  if [ -z "$SIGNING_KEY_HEX" ]; then
    log_warn "SIGNING_KEY_HEX not set in keys/signing_keys.env"
  else
    log_ok "SIGNING_KEY_HEX set (${#SIGNING_KEY_HEX} chars)"
  fi
  
  if [ -z "$PUBLIC_KEY_HEX" ]; then
    log_warn "PUBLIC_KEY_HEX not set in keys/signing_keys.env"
  else
    log_ok "PUBLIC_KEY_HEX set (${#PUBLIC_KEY_HEX} chars)"
  fi
else
  log_warn "keys/signing_keys.env not found (run: ./generate_keys.sh)"
fi

# 5. Check Node.js dependencies
echo ""
echo "📦 Checking Node.js dependencies..."
if ! command -v node &> /dev/null; then
  log_fail "Node.js not installed"
  echo "Please install Node.js 20+: https://nodejs.org/"
  exit 1
fi

NODE_VERSION=$(node --version)
log_ok "Node.js installed ($NODE_VERSION)"

if [ -d "src/stage0/node_modules" ]; then
  log_ok "Stage-0 dependencies installed"
else
  log_warn "Stage-0 dependencies not installed"
  echo "  Run: cd src/stage0 && npm install --production"
fi

if [ -d "src/kernels/node_modules" ]; then
  log_ok "Kernel dependencies installed"
else
  log_warn "Kernel dependencies not installed"
  echo "  Run: cd src/kernels && npm install --production"
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

if grep -q "manifest" infra/scripts/seed_manifest.sql; then
  log_ok "seed_manifest.sql looks valid"
else
  log_fail "seed_manifest.sql appears incomplete"
  exit 1
fi

# 7. Check terraform.tfvars
echo ""
echo "⚙️  Checking Terraform configuration..."
if [ -f "infra/terraform.tfvars" ]; then
  log_ok "infra/terraform.tfvars exists"
else
  log_warn "infra/terraform.tfvars not found"
  echo "  Copy from example: cp infra/terraform.tfvars.example infra/terraform.tfvars"
  echo "  Then edit with your values"
fi

echo ""
if [ "$1" == "--strict" ]; then
  # Strict mode - fail on warnings
  if [ -f "keys/db_credentials.env" ] && [ -f "keys/signing_keys.env" ] && [ -f "infra/terraform.tfvars" ]; then
    log_ok "All validation checks passed!"
  else
    log_fail "Some checks failed in strict mode"
    exit 1
  fi
else
  log_ok "Validation complete!"
fi

echo ""
echo "✅ Ready to proceed!"
echo ""
echo "Next steps:"
echo "  1. Generate credentials (if not done):"
echo "     ./generate_keys.sh"
echo "     ./generate_db_password.sh"
echo ""
echo "  2. Install dependencies:"
echo "     cd src/stage0 && npm install --production && cd ../.."
echo "     cd src/kernels && npm install --production && cd ../.."
echo ""
echo "  3. Configure Terraform:"
echo "     cd infra"
echo "     cp terraform.tfvars.example terraform.tfvars"
echo "     # Edit terraform.tfvars with your values"
echo ""
echo "  4. Deploy:"
echo "     ./deploy_logline.sh"
echo ""
