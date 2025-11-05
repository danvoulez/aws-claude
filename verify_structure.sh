#!/bin/bash

echo "🔍 LogLine File Structure Verification"
echo "======================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1 (MISSING)"
        ((errors++))
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
    else
        echo -e "${RED}✗${NC} $1/ (MISSING)"
        ((errors++))
    fi
}

echo "📁 Root Files"
check_file "README.md"
check_file "PLAN.MD"
check_file "IMPLEMENTATION_STATUS.md"
check_file ".gitignore"

echo ""
echo "🔧 Helper Scripts"
check_file "deploy_logline.sh"
check_file "connect_db.sh"
check_file "generate_keys.sh"
check_file "generate_db_password.sh"

echo ""
echo "📂 Infrastructure Root"
check_file "infra/main.tf"
check_file "infra/variables.tf"
check_file "infra/outputs.tf"
check_file "infra/terraform.tfvars.example"

echo ""
echo "🗄️  Database Module (COMPLETE)"
check_dir "infra/modules/database"
check_file "infra/modules/database/main.tf"
check_file "infra/modules/database/security.tf"
check_file "infra/modules/database/variables.tf"
check_file "infra/modules/database/outputs.tf"

echo ""
echo "📜 SQL Scripts"
check_file "infra/scripts/init_db.sql"
check_file "infra/scripts/seed_manifest.sql"
check_file "infra/scripts/seed_kernels.sql"

echo ""
echo "🚀 Stage-0 Module (PLACEHOLDER)"
check_dir "infra/modules/stage0"
check_file "infra/modules/stage0/main.tf"
check_file "infra/modules/stage0/variables.tf"
check_file "infra/modules/stage0/outputs.tf"

echo ""
echo "⚙️  Kernels Module (PLACEHOLDER)"
check_dir "infra/modules/kernels"
check_file "infra/modules/kernels/main.tf"
check_file "infra/modules/kernels/variables.tf"
check_file "infra/modules/kernels/outputs.tf"

echo ""
echo "🌐 API Module (PLACEHOLDER)"
check_dir "infra/modules/api"
check_file "infra/modules/api/main.tf"
check_file "infra/modules/api/variables.tf"
check_file "infra/modules/api/outputs.tf"

echo ""
echo "⏰ Scheduler Module (PLACEHOLDER)"
check_dir "infra/modules/scheduler"
check_file "infra/modules/scheduler/main.tf"
check_file "infra/modules/scheduler/variables.tf"
check_file "infra/modules/scheduler/outputs.tf"

echo ""
echo "🔐 Secrets Module (PLACEHOLDER)"
check_dir "infra/modules/secrets"
check_file "infra/modules/secrets/main.tf"
check_file "infra/modules/secrets/variables.tf"
check_file "infra/modules/secrets/outputs.tf"

echo ""
echo "======================================"
echo "📊 Verification Summary"
echo "======================================"

if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ All files present!${NC}"
    echo ""
    echo "Phase 1 (Database) is ready to deploy:"
    echo "  ./generate_keys.sh"
    echo "  ./generate_db_password.sh"
    echo "  cd infra && terraform init"
    echo "  terraform apply -target=module.database"
    echo ""
    echo "Phases 2-6 have module structure ready for implementation."
    echo "See IMPLEMENTATION_STATUS.md for details."
    exit 0
else
    echo -e "${RED}❌ $errors file(s) missing${NC}"
    echo "Please review the errors above."
    exit 1
fi
