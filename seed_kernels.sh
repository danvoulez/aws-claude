#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "════════════════════════════════════"
echo "    Seeding Kernel Functions"
echo "════════════════════════════════════"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
  log_fail "psql not found"
  echo "Please install PostgreSQL client to seed kernels"
  exit 1
fi

# Get connection string from Terraform
cd infra
if [ ! -f "terraform.tfstate" ]; then
  log_fail "Terraform state not found. Deploy infrastructure first."
  exit 1
fi

CONN_STRING=$(terraform output -raw connection_string 2>/dev/null)
if [ -z "$CONN_STRING" ]; then
  log_fail "Database connection string not available"
  exit 1
fi

log_info "Database: $(terraform output -raw database_endpoint)"
cd ..

# Seed manifest
log_info "Seeding manifest..."
if psql "$CONN_STRING" < infra/scripts/seed_manifest.sql > /dev/null; then
  log_ok "Manifest seeded"
else
  log_fail "Failed to seed manifest"
  exit 1
fi

# Seed kernels
log_info "Seeding kernel functions..."
if psql "$CONN_STRING" < infra/scripts/seed_kernels.sql > /dev/null; then
  log_ok "Kernels seeded"
else
  log_fail "Failed to seed kernels"
  exit 1
fi

# Verify
log_info "Verifying kernel data..."
KERNEL_COUNT=$(psql "$CONN_STRING" -t -c "SELECT COUNT(*) FROM ledger.universal_registry WHERE entity_type = 'function';" | tr -d ' ')

if [ "$KERNEL_COUNT" -ge 5 ]; then
  log_ok "Found $KERNEL_COUNT kernel functions in database"
else
  log_fail "Expected at least 5 kernels, found $KERNEL_COUNT"
  exit 1
fi

# Show kernels
echo ""
log_info "Kernel functions in database:"
psql "$CONN_STRING" -c "SELECT id, name, entity_type, status FROM ledger.universal_registry WHERE entity_type = 'function' ORDER BY name;"

echo ""
log_ok "Kernel seeding complete!"
echo ""
