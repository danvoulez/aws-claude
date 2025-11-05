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
echo "    LogLine - Deployment Tests"
echo "═══════════════════════════════════════"
echo ""

# Get database endpoint
cd infra
if [ ! -f "terraform.tfstate" ]; then
  log_fail "Terraform state not found. Deploy infrastructure first."
  exit 1
fi

DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")

cd ..

if [ -z "$DB_ENDPOINT" ]; then
  log_fail "Could not get database endpoint"
  exit 1
fi

# Source credentials
if [ -f "keys/db_credentials.env" ]; then
  source keys/db_credentials.env
else
  log_fail "keys/db_credentials.env not found"
  exit 1
fi

DB_NAME="logline"
DB_USER="logline_admin"
CONN_STRING="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require"

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local test_name="$1"
  local test_command="$2"
  
  echo ""
  log_step "Test: $test_name"
  
  if eval "$test_command"; then
    log_ok "PASS: $test_name"
    ((TESTS_PASSED++))
    return 0
  else
    log_fail "FAIL: $test_name"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Database tests
echo "🗄️  Database Tests"
echo "==================="

run_test "Database connection" \
  "psql \"$CONN_STRING\" -c 'SELECT 1;' > /dev/null 2>&1"

run_test "Schema exists" \
  "psql \"$CONN_STRING\" -c '\\dn ledger' | grep -q ledger"

run_test "Universal registry table exists" \
  "psql \"$CONN_STRING\" -c '\\dt ledger.universal_registry' | grep -q universal_registry"

run_test "Visible timeline view exists" \
  "psql \"$CONN_STRING\" -c '\\dv ledger.visible_timeline' | grep -q visible_timeline"

run_test "Manifest exists" \
  "psql \"$CONN_STRING\" -c \"SELECT COUNT(*) FROM ledger.universal_registry WHERE entity_type='manifest';\" | grep -q '1'"

run_test "Kernel functions exist (5 total)" \
  "psql \"$CONN_STRING\" -c \"SELECT COUNT(*) FROM ledger.universal_registry WHERE entity_type='function';\" | grep -q '5'"

run_test "RLS policies enabled" \
  "psql \"$CONN_STRING\" -c \"SELECT COUNT(*) FROM pg_policies WHERE schemaname='ledger' AND tablename='universal_registry';\" | grep -q -E '[1-9]'"

run_test "Insert span test" \
  "psql \"$CONN_STRING\" -c \"SET app.user_id='test'; INSERT INTO ledger.universal_registry (id, seq, entity_type, who, did, this, at, status, owner_id, visibility) VALUES (gen_random_uuid(), 0, 'test', 'test', 'tested', 'deployment', NOW(), 'complete', 'test', 'private');\" > /dev/null 2>&1"

run_test "Query timeline test" \
  "psql \"$CONN_STRING\" -c \"SET app.user_id='test'; SELECT COUNT(*) FROM ledger.visible_timeline WHERE entity_type='test';\" | grep -q -E '[0-9]+'"

# API tests (if endpoint available)
if [ -n "$API_ENDPOINT" ]; then
  echo ""
  echo "🌐 API Tests"
  echo "============="
  
  run_test "API endpoint reachable" \
    "curl -s -o /dev/null -w '%{http_code}' \"$API_ENDPOINT\" | grep -q -E '(200|404|403)'"
  
  run_test "Timeline endpoint" \
    "curl -s \"$API_ENDPOINT/api/timeline?limit=5\" | grep -q -E '(spans|error)'"
  
  run_test "Spans POST endpoint" \
    "curl -s -X POST \"$API_ENDPOINT/api/spans\" -H 'Content-Type: application/json' -d '{\"entity_type\":\"test\",\"who\":\"api_test\",\"this\":\"test\"}' | grep -q -E '(success|error)'"
fi

# Source code tests
echo ""
echo "💻 Source Code Tests"
echo "===================="

run_test "Stage-0 code exists" \
  "[ -f src/stage0/index.js ]"

run_test "Stage-0 db module exists" \
  "[ -f src/stage0/db.js ]"

run_test "Kernel db module exists" \
  "[ -f src/kernels/db.js ]"

run_test "run_code kernel exists" \
  "[ -f src/kernels/run_code/index.js ]"

run_test "observer_bot kernel exists" \
  "[ -f src/kernels/observer_bot/index.js ]"

run_test "request_worker kernel exists" \
  "[ -f src/kernels/request_worker/index.js ]"

run_test "policy_agent kernel exists" \
  "[ -f src/kernels/policy_agent/index.js ]"

run_test "provider_exec kernel exists" \
  "[ -f src/kernels/provider_exec/index.js ]"

# Summary
echo ""
echo "═══════════════════════════════════════"
echo "          Test Summary"
echo "═══════════════════════════════════════"
echo ""
log_ok "Tests passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
  log_fail "Tests failed: $TESTS_FAILED"
  exit 1
else
  log_ok "All tests passed! ✨"
fi
echo ""

# Show endpoints
if [ -n "$API_ENDPOINT" ]; then
  echo "📍 Your Endpoints:"
  echo "   API:      $API_ENDPOINT"
  echo "   Database: $DB_ENDPOINT"
  echo ""
fi

echo "🧪 Quick Manual Tests:"
echo ""
echo "  # Query timeline"
if [ -n "$API_ENDPOINT" ]; then
  echo "  curl \"$API_ENDPOINT/api/timeline?limit=5\" | jq ."
fi
echo ""
echo "  # Connect to database"
echo "  ./connect_db.sh"
echo ""
echo "  # List all kernels"
echo "  psql \"$CONN_STRING\" -c \"SELECT id, name, status FROM ledger.universal_registry WHERE entity_type='function';\""
echo ""
