#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}▶${NC} TEST: $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "═══════════════════════════════════════"
echo "    LogLine OS - Deployment Tests"
echo "═══════════════════════════════════════"
echo ""

# Get API endpoint
cd infra
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
cd ..

if [ -z "$API_ENDPOINT" ]; then
  log_fail "API endpoint not found. Deploy infrastructure first."
  exit 1
fi

echo "🔗 Testing endpoint: $API_ENDPOINT"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: API Gateway is accessible
log_test "API Gateway is accessible"
if curl -s -o /dev/null -w "%{http_code}" "$API_ENDPOINT/api/timeline?limit=1" | grep -q "200\|500"; then
  log_ok "API Gateway is accessible"
  ((PASS_COUNT++))
else
  log_fail "API Gateway is not accessible"
  ((FAIL_COUNT++))
fi

# Test 2: Query timeline
log_test "Query timeline endpoint"
TIMELINE_RESPONSE=$(curl -s "$API_ENDPOINT/api/timeline?limit=5")
if echo "$TIMELINE_RESPONSE" | jq -e '.spans' > /dev/null 2>&1; then
  log_ok "Timeline endpoint returns valid JSON with spans"
  SPAN_COUNT=$(echo "$TIMELINE_RESPONSE" | jq -r '.count')
  echo "   Found $SPAN_COUNT spans"
  ((PASS_COUNT++))
else
  log_fail "Timeline endpoint failed or returned invalid JSON"
  echo "$TIMELINE_RESPONSE"
  ((FAIL_COUNT++))
fi

# Test 3: Insert test span
log_test "Insert test span"
INSERT_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/api/spans" \
  -H 'Content-Type: application/json' \
  -d '{
    "entity_type": "test",
    "who": "test_deployment_script",
    "this": "automated_test",
    "metadata": {"test_run": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}
  }')

if echo "$INSERT_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
  SUCCESS=$(echo "$INSERT_RESPONSE" | jq -r '.success')
  if [ "$SUCCESS" = "true" ]; then
    log_ok "Successfully inserted test span"
    SPAN_ID=$(echo "$INSERT_RESPONSE" | jq -r '.span.id')
    echo "   Span ID: $SPAN_ID"
    ((PASS_COUNT++))
  else
    log_fail "Insert span returned success=false"
    echo "$INSERT_RESPONSE"
    ((FAIL_COUNT++))
  fi
else
  log_fail "Insert span failed or returned invalid JSON"
  echo "$INSERT_RESPONSE"
  ((FAIL_COUNT++))
fi

# Test 4: Query timeline with filters
log_test "Query timeline with entity_type filter"
FILTER_RESPONSE=$(curl -s "$API_ENDPOINT/api/timeline?entity_type=test&limit=5")
if echo "$FILTER_RESPONSE" | jq -e '.spans' > /dev/null 2>&1; then
  log_ok "Timeline filter by entity_type works"
  ((PASS_COUNT++))
else
  log_fail "Timeline filter failed"
  ((FAIL_COUNT++))
fi

# Test 5: Check if manifest exists in timeline
log_test "Check manifest in timeline"
MANIFEST_RESPONSE=$(curl -s "$API_ENDPOINT/api/timeline?entity_type=manifest&limit=1")
if echo "$MANIFEST_RESPONSE" | jq -e '.spans[0]' > /dev/null 2>&1; then
  log_ok "Manifest found in timeline"
  MANIFEST_NAME=$(echo "$MANIFEST_RESPONSE" | jq -r '.spans[0].name')
  echo "   Manifest: $MANIFEST_NAME"
  ((PASS_COUNT++))
else
  log_fail "Manifest not found in timeline"
  ((FAIL_COUNT++))
fi

# Test 6: Check database connection (if psql available)
if command -v psql &> /dev/null; then
  log_test "Direct database connection"
  cd infra
  CONN_STRING=$(terraform output -raw connection_string 2>/dev/null || echo "")
  cd ..
  
  if [ -n "$CONN_STRING" ]; then
    if psql "$CONN_STRING" -c "SELECT COUNT(*) FROM ledger.universal_registry;" > /dev/null 2>&1; then
      ROW_COUNT=$(psql "$CONN_STRING" -t -c "SELECT COUNT(*) FROM ledger.universal_registry;")
      log_ok "Database connection successful"
      echo "   Total spans in registry: $ROW_COUNT"
      ((PASS_COUNT++))
    else
      log_fail "Database connection failed"
      ((FAIL_COUNT++))
    fi
  else
    log_fail "Database connection string not available"
    ((FAIL_COUNT++))
  fi
else
  echo "   Skipping database test (psql not installed)"
fi

# Test 7: Check Lambda functions exist
log_test "Lambda functions deployed"
STAGE0_EXISTS=$(aws lambda get-function --function-name logline-dev-stage0 2>/dev/null && echo "yes" || echo "no")
if [ "$STAGE0_EXISTS" = "yes" ]; then
  log_ok "Stage-0 Lambda deployed"
  ((PASS_COUNT++))
else
  log_fail "Stage-0 Lambda not found"
  ((FAIL_COUNT++))
fi

# Summary
echo ""
echo "═══════════════════════════════════════"
echo "    Test Summary"
echo "═══════════════════════════════════════"
echo ""
echo "✅ Passed: $PASS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  log_ok "All tests passed!"
  exit 0
else
  log_fail "Some tests failed"
  exit 1
fi
