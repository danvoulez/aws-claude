-- Seed kernel function spans
-- Run this after the database and manifest are initialized

SET app.user_id = 'bootstrap:terraform';
SET app.tenant_id = 'voulezvous';

-- Note: The actual kernel code would be inserted here
-- This is a placeholder that shows the structure for the 5 core kernels

-- 1. run_code_kernel (00000000-0000-4000-8000-000000000001)
-- Purpose: Executes user-defined functions with sandboxing, quota enforcement, and timeout
INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, name, description, language, runtime, owner_id, tenant_id, visibility, metadata)
VALUES
  ('00000000-0000-4000-8000-000000000001', 0, 'function', 'bootstrap:terraform', 'defined', 'function', now(), 'active',
   'run_code_kernel',
   'Executes user-defined functions with sandboxing, quota enforcement, and timeout',
   'javascript', 'nodejs20.x',
   'bootstrap:terraform', 'voulezvous', 'tenant',
   jsonb_build_object(
     'timeout', 60,
     'memory', 512,
     'features', jsonb_build_array('advisory_lock', 'quota_check', 'timeout_enforcement')
   ));

-- 2. observer_bot_kernel (00000000-0000-4000-8000-000000000002)
-- Purpose: Monitors for status='scheduled' spans and emits request spans
INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, name, description, language, runtime, owner_id, tenant_id, visibility, metadata)
VALUES
  ('00000000-0000-4000-8000-000000000002', 0, 'function', 'bootstrap:terraform', 'defined', 'function', now(), 'active',
   'observer_bot_kernel',
   'Monitors for scheduled spans and emits request spans',
   'javascript', 'nodejs20.x',
   'bootstrap:terraform', 'voulezvous', 'tenant',
   jsonb_build_object(
     'schedule', 'rate(10 seconds)',
     'batch_size', 16,
     'features', jsonb_build_array('idempotent_requests', 'quota_aware', 'lock_based')
   ));

-- 3. request_worker_kernel (00000000-0000-4000-8000-000000000003)
-- Purpose: Processes request spans by invoking the appropriate kernel
INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, name, description, language, runtime, owner_id, tenant_id, visibility, metadata)
VALUES
  ('00000000-0000-4000-8000-000000000003', 0, 'function', 'bootstrap:terraform', 'defined', 'function', now(), 'active',
   'request_worker_kernel',
   'Processes request spans by invoking the appropriate kernel',
   'javascript', 'nodejs20.x',
   'bootstrap:terraform', 'voulezvous', 'tenant',
   jsonb_build_object(
     'schedule', 'rate(10 seconds)',
     'batch_size', 8,
     'features', jsonb_build_array('fifo_processing', 'advisory_lock')
   ));

-- 4. policy_agent_kernel (00000000-0000-4000-8000-000000000004)
-- Purpose: Evaluates active policies against new spans, emits action spans
INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, name, description, language, runtime, owner_id, tenant_id, visibility, metadata)
VALUES
  ('00000000-0000-4000-8000-000000000004', 0, 'function', 'bootstrap:terraform', 'defined', 'function', now(), 'active',
   'policy_agent_kernel',
   'Evaluates active policies against new spans and emits action spans',
   'javascript', 'nodejs20.x',
   'bootstrap:terraform', 'voulezvous', 'tenant',
   jsonb_build_object(
     'schedule', 'rate(30 seconds)',
     'batch_size', 500,
     'features', jsonb_build_array('cursor_based', 'sandboxed_eval', 'error_logging')
   ));

-- 5. provider_exec_kernel (00000000-0000-4000-8000-000000000005)
-- Purpose: Calls external APIs (OpenAI, Ollama, etc.)
INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, name, description, language, runtime, owner_id, tenant_id, visibility, metadata)
VALUES
  ('00000000-0000-4000-8000-000000000005', 0, 'function', 'bootstrap:terraform', 'defined', 'function', now(), 'active',
   'provider_exec_kernel',
   'Calls external APIs (OpenAI, Ollama, etc.)',
   'javascript', 'nodejs20.x',
   'bootstrap:terraform', 'voulezvous', 'tenant',
   jsonb_build_object(
     'timeout', 120,
     'memory', 1024,
     'features', jsonb_build_array('multi_provider', 'api_key_management', 'response_logging')
   ));

-- Verify all kernels were inserted
SELECT
  id,
  name,
  entity_type,
  status,
  description
FROM ledger.universal_registry
WHERE entity_type = 'function'
  AND id IN (
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000005'
  )
ORDER BY id;
