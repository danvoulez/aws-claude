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
echo "    LogLine - Seed Kernel Functions"
echo "═══════════════════════════════════════"
echo ""

# Check if we're in the right directory
if [ ! -f "infra/scripts/seed_manifest.sql" ]; then
  log_fail "Must run from repository root"
  exit 1
fi

# Get database connection string
cd infra
if [ ! -f "terraform.tfstate" ]; then
  log_fail "Terraform state not found. Deploy infrastructure first."
  exit 1
fi

DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")
if [ -z "$DB_ENDPOINT" ]; then
  log_fail "Could not get database endpoint from Terraform"
  exit 1
fi

cd ..

# Source credentials
if [ -f "keys/db_credentials.env" ]; then
  source keys/db_credentials.env
else
  log_fail "keys/db_credentials.env not found"
  echo "Run: ./generate_db_password.sh"
  exit 1
fi

if [ -f "keys/signing_keys.env" ]; then
  source keys/signing_keys.env
else
  log_fail "keys/signing_keys.env not found"
  echo "Run: ./generate_keys.sh"
  exit 1
fi

# Construct connection string
DB_NAME="logline"
DB_USER="logline_admin"
CONN_STRING="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require"

log_step "Seeding manifest..."
psql "$CONN_STRING" -f infra/scripts/seed_manifest.sql
log_ok "Manifest seeded"

log_step "Seeding kernel functions..."

# Create a temporary SQL file with kernel code
cat > /tmp/seed_kernels_code.sql <<'EOSQL'
-- Set session context
SET app.user_id = 'system';
SET app.tenant_id = 'logline';

-- Insert run_code kernel
INSERT INTO ledger.universal_registry (
  id, seq, entity_type, who, did, "this", at, status,
  name, description, code, language, runtime,
  owner_id, tenant_id, visibility, is_deleted,
  metadata
) VALUES (
  '00000000-0000-4000-8000-000000000001'::uuid,
  0,
  'function',
  'system',
  'created',
  'run_code_kernel',
  NOW(),
  'active',
  'run_code',
  'Execute code from pending requests',
  E'export async function main(ctx) {\n  const { sql, insertSpan, now } = ctx;\n  const { rows } = await sql`SELECT * FROM ledger.visible_timeline WHERE entity_type = \'code_request\' AND status = \'pending\' LIMIT 10`;\n  for (const request of rows) {\n    try {\n      const code = request.code || request.input?.code;\n      const factory = new Function(\'ctx\', `"use strict";\\n${code}\\n;return main;`);\n      const fn = factory(ctx);\n      const result = await fn(ctx);\n      await insertSpan({ id: request.id, seq: (request.seq || 0) + 1, entity_type: \'code_execution\', who: \'kernel:run_code\', did: \'executed\', this: request.this, at: now(), status: \'complete\', output: { result }, owner_id: request.owner_id, tenant_id: request.tenant_id, visibility: request.visibility });\n    } catch (error) {\n      await insertSpan({ id: request.id, seq: (request.seq || 0) + 1, entity_type: \'code_execution\', who: \'kernel:run_code\', did: \'failed\', this: request.this, at: now(), status: \'error\', error: { message: error.message }, owner_id: request.owner_id, tenant_id: request.tenant_id, visibility: request.visibility });\n    }\n  }\n  return { success: true, kernel: \'run_code\', processed: rows.length };\n}',
  'javascript',
  'nodejs20.x',
  'system',
  'logline',
  'public',
  false,
  '{"version":"1.0.0","kernel_type":"executor"}'::jsonb
);

-- Insert observer_bot kernel
INSERT INTO ledger.universal_registry (
  id, seq, entity_type, who, did, "this", at, status,
  name, description, code, language, runtime,
  owner_id, tenant_id, visibility, is_deleted,
  metadata
) VALUES (
  '00000000-0000-4000-8000-000000000002'::uuid,
  0,
  'function',
  'system',
  'created',
  'observer_bot_kernel',
  NOW(),
  'active',
  'observer_bot',
  'Monitor timeline for anomalies',
  E'export async function main(ctx) {\n  const { sql, insertSpan, now } = ctx;\n  const { rows } = await sql`SELECT * FROM ledger.visible_timeline WHERE at > NOW() - INTERVAL \'30 seconds\' LIMIT 100`;\n  let anomalies = 0;\n  for (const span of rows) {\n    if (span.entity_type === \'function\' && !span.signature) {\n      await insertSpan({ id: crypto.randomUUID(), seq: 0, entity_type: \'observation\', who: \'kernel:observer_bot\', did: \'detected_unsigned\', this: \'anomaly\', at: now(), status: \'alert\', input: { span_id: span.id, issue: \'unsigned_function\' }, owner_id: span.owner_id, tenant_id: span.tenant_id, visibility: \'private\' });\n      anomalies++;\n    }\n  }\n  return { success: true, kernel: \'observer_bot\', checked: rows.length, anomalies };\n}',
  'javascript',
  'nodejs20.x',
  'system',
  'logline',
  'public',
  false,
  '{"version":"1.0.0","kernel_type":"monitor"}'::jsonb
);

-- Insert request_worker kernel
INSERT INTO ledger.universal_registry (
  id, seq, entity_type, who, did, "this", at, status,
  name, description, code, language, runtime,
  owner_id, tenant_id, visibility, is_deleted,
  metadata
) VALUES (
  '00000000-0000-4000-8000-000000000003'::uuid,
  0,
  'function',
  'system',
  'created',
  'request_worker_kernel',
  NOW(),
  'active',
  'request_worker',
  'Process pending requests',
  E'export async function main(ctx) {\n  const { sql, insertSpan, now } = ctx;\n  const { rows } = await sql`SELECT * FROM ledger.visible_timeline WHERE entity_type = \'request\' AND status = \'pending\' LIMIT 10`;\n  for (const request of rows) {\n    try {\n      await insertSpan({ id: request.id, seq: (request.seq || 0) + 1, entity_type: \'request_result\', who: \'kernel:request_worker\', did: \'processed\', this: request.this, at: now(), status: \'complete\', output: { processed: true }, owner_id: request.owner_id, tenant_id: request.tenant_id, visibility: request.visibility });\n    } catch (error) {\n      await insertSpan({ id: request.id, seq: (request.seq || 0) + 1, entity_type: \'request_result\', who: \'kernel:request_worker\', did: \'failed\', this: request.this, at: now(), status: \'error\', error: { message: error.message }, owner_id: request.owner_id, tenant_id: request.tenant_id, visibility: request.visibility });\n    }\n  }\n  return { success: true, kernel: \'request_worker\', processed: rows.length };\n}',
  'javascript',
  'nodejs20.x',
  'system',
  'logline',
  'public',
  false,
  '{"version":"1.0.0","kernel_type":"worker"}'::jsonb
);

-- Insert policy_agent kernel
INSERT INTO ledger.universal_registry (
  id, seq, entity_type, who, did, "this", at, status,
  name, description, code, language, runtime,
  owner_id, tenant_id, visibility, is_deleted,
  metadata
) VALUES (
  '00000000-0000-4000-8000-000000000004'::uuid,
  0,
  'function',
  'system',
  'created',
  'policy_agent_kernel',
  NOW(),
  'active',
  'policy_agent',
  'Enforce governance policies',
  E'export async function main(ctx) {\n  const { sql, insertSpan, now } = ctx;\n  const { rows } = await sql`SELECT * FROM ledger.visible_timeline WHERE at > NOW() - INTERVAL \'1 minute\' LIMIT 50`;\n  let violations = 0;\n  for (const span of rows) {\n    if (!span.visibility || ![\'public\', \'private\', \'shared\'].includes(span.visibility)) {\n      await insertSpan({ id: crypto.randomUUID(), seq: 0, entity_type: \'policy_check\', who: \'kernel:policy_agent\', did: \'detected_violation\', this: \'policy\', at: now(), status: \'violation\', input: { span_id: span.id, violation: \'invalid_visibility\' }, owner_id: span.owner_id, tenant_id: span.tenant_id, visibility: \'private\' });\n      violations++;\n    }\n  }\n  return { success: true, kernel: \'policy_agent\', checked: rows.length, violations };\n}',
  'javascript',
  'nodejs20.x',
  'system',
  'logline',
  'public',
  false,
  '{"version":"1.0.0","kernel_type":"enforcer"}'::jsonb
);

-- Insert provider_exec kernel
INSERT INTO ledger.universal_registry (
  id, seq, entity_type, who, did, "this", at, status,
  name, description, code, language, runtime,
  owner_id, tenant_id, visibility, is_deleted,
  metadata
) VALUES (
  '00000000-0000-4000-8000-000000000005'::uuid,
  0,
  'function',
  'system',
  'created',
  'provider_exec_kernel',
  NOW(),
  'active',
  'provider_exec',
  'Execute external provider requests',
  E'export async function main(ctx) {\n  const { sql, insertSpan, now } = ctx;\n  const { rows } = await sql`SELECT * FROM ledger.visible_timeline WHERE entity_type = \'provider_request\' AND status = \'pending\' LIMIT 5`;\n  for (const request of rows) {\n    try {\n      const provider = request.input?.provider;\n      await insertSpan({ id: request.id, seq: (request.seq || 0) + 1, entity_type: \'provider_result\', who: \'kernel:provider_exec\', did: \'executed\', this: request.this, at: now(), status: \'complete\', output: { provider }, owner_id: request.owner_id, tenant_id: request.tenant_id, visibility: request.visibility });\n    } catch (error) {\n      await insertSpan({ id: request.id, seq: (request.seq || 0) + 1, entity_type: \'provider_result\', who: \'kernel:provider_exec\', did: \'failed\', this: request.this, at: now(), status: \'error\', error: { message: error.message }, owner_id: request.owner_id, tenant_id: request.tenant_id, visibility: request.visibility });\n    }\n  }\n  return { success: true, kernel: \'provider_exec\', processed: rows.length };\n}',
  'javascript',
  'nodejs20.x',
  'system',
  'logline',
  'public',
  false,
  '{"version":"1.0.0","kernel_type":"provider"}'::jsonb
);
EOSQL

psql "$CONN_STRING" -f /tmp/seed_kernels_code.sql
rm /tmp/seed_kernels_code.sql

log_ok "Kernel functions seeded"

echo ""
log_step "Verifying kernels in database..."
psql "$CONN_STRING" -c "SELECT id, name, entity_type, status FROM ledger.universal_registry WHERE entity_type = 'function' ORDER BY name;"

echo ""
log_ok "✅ All 5 kernel functions seeded successfully!"
echo ""
