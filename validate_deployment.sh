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
  "infra/terraform.tfvars.example"
  "infra/modules/database/main.tf"
  "infra/modules/secrets/main.tf"
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
  REGION=$(aws configure get region || echo "not-set")
  log_ok "AWS authenticated (Account: $ACCOUNT, Region: $REGION)"
else
  log_fail "AWS not configured"
  exit 1
fi

# 3. Check Terraform
echo ""
echo "🔧 Checking Terraform..."
if ! command -v terraform &> /dev/null; then
  log_fail "Terraform not installed"
  exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
log_ok "Terraform $TERRAFORM_VERSION installed"

cd infra
if terraform validate &> /dev/null; then
  log_ok "Terraform configuration valid"
else
  log_fail "Terraform validation failed"
  terraform validate
  exit 1
fi
cd ..

# 4. Check terraform.tfvars
echo ""
echo "🔑 Checking terraform.tfvars..."
if [ ! -f "infra/terraform.tfvars" ]; then
  log_fail "infra/terraform.tfvars not found"
  echo "   Please copy terraform.tfvars.example to terraform.tfvars and fill in your values"
  exit 1
else
  log_ok "terraform.tfvars exists"
  
  # Check if signing keys are set
  if grep -q "YOUR_SIGNING_KEY_HEX_HERE" infra/terraform.tfvars 2>/dev/null; then
    log_fail "Signing keys not set in terraform.tfvars"
    echo "   Run ./generate_keys.sh to generate cryptographic keys"
    exit 1
  else
    log_ok "Signing keys configured"
  fi
  
  # Check if DB password is changed
  if grep -q "CHANGE_ME_TO_STRONG_PASSWORD" infra/terraform.tfvars 2>/dev/null; then
    log_fail "Database password not set in terraform.tfvars"
    echo "   Run ./generate_db_password.sh to generate a secure password"
    exit 1
  else
    log_ok "Database password configured"
  fi
fi

# 5. Check Node.js
echo ""
echo "📦 Checking Node.js..."
if ! command -v node &> /dev/null; then
  log_fail "Node.js not installed"
  exit 1
fi

NODE_VERSION=$(node --version)
log_ok "Node.js $NODE_VERSION installed"

if ! command -v npm &> /dev/null; then
  log_fail "npm not installed"
  exit 1
fi

NPM_VERSION=$(npm --version)
log_ok "npm $NPM_VERSION installed"

# 6. Check PostgreSQL client
echo ""
echo "🗄️  Checking PostgreSQL client..."
if ! command -v psql &> /dev/null; then
  log_warn "psql not installed (required for manual DB connection)"
else
  PSQL_VERSION=$(psql --version)
  log_ok "$PSQL_VERSION installed"
fi

# 7. Check SQL files
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

if grep -q "run_code" infra/scripts/seed_kernels.sql; then
  log_ok "seed_kernels.sql looks valid"
else
  log_fail "seed_kernels.sql missing kernel definitions"
  exit 1
fi

echo ""
log_ok "All validation checks passed!"
echo ""
echo "✅ Ready to deploy!"
echo ""
echo "Next steps:"
echo "  1. terraform init       # Initialize Terraform"
echo "  2. terraform plan        # Preview changes"
echo "  3. terraform apply       # Deploy infrastructure"
echo ""
echo "Or use the automated deployment:"
echo "  ./deploy_logline.sh      # One-command deployment"
echo ""
