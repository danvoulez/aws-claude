#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

test_pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASSED++))
}

test_fail() {
  echo -e "${RED}✗${NC} $1"
  ((FAILED++))
}

echo "🧪 LogLine Deployment Tests"
echo "==========================="
echo ""

# Test 1: Check if infra directory exists
echo "📁 Infrastructure Tests"
if [ -d "infra" ]; then
  test_pass "Infrastructure directory exists"
else
  test_fail "Infrastructure directory missing"
fi

# Test 2: Check Terraform state
cd infra
if [ -f "terraform.tfstate" ]; then
  test_pass "Terraform state exists"
else
  test_fail "Terraform state missing - run deployment first"
fi

# Test 3: Check database endpoint
if terraform output -raw database_endpoint &> /dev/null; then
  DB_ENDPOINT=$(terraform output -raw database_endpoint)
  test_pass "Database endpoint: $DB_ENDPOINT"
else
  test_fail "Database endpoint not available"
fi

# Test 4: Check if we can connect to database
if terraform output -raw connection_string &> /dev/null; then
  CONNECTION_STRING=$(terraform output -raw connection_string)
  if psql "$CONNECTION_STRING" -c "SELECT 1;" &> /dev/null; then
    test_pass "Database connectivity verified"
  else
    test_fail "Cannot connect to database"
  fi
else
  test_fail "Connection string not available"
fi

# Test 5: Check if universal_registry table exists
if psql "$CONNECTION_STRING" -c "\dt ledger.universal_registry" &> /dev/null; then
  test_pass "Universal registry table exists"
else
  test_fail "Universal registry table missing"
fi

# Test 6: Check if manifest exists
MANIFEST_COUNT=$(psql "$CONNECTION_STRING" -t -c "SELECT COUNT(*) FROM ledger.universal_registry WHERE entity_type='manifest';" | tr -d ' ')
if [ "$MANIFEST_COUNT" -gt "0" ]; then
  test_pass "Manifest exists ($MANIFEST_COUNT found)"
else
  test_fail "Manifest missing"
fi

# Test 7: Check if kernels exist
KERNEL_COUNT=$(psql "$CONNECTION_STRING" -t -c "SELECT COUNT(*) FROM ledger.universal_registry WHERE entity_type='function';" | tr -d ' ')
if [ "$KERNEL_COUNT" -ge "5" ]; then
  test_pass "Kernels seeded ($KERNEL_COUNT found)"
else
  test_fail "Kernels missing or incomplete (found $KERNEL_COUNT, expected 5)"
fi

cd ..

# Summary
echo ""
echo "📊 Test Summary"
echo "==============="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "✅ All tests passed! 🎉"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi
