-- Seed the initial manifest
-- Run this after init_db.sql

SET app.user_id = 'bootstrap:terraform';
SET app.tenant_id = 'voulezvous';

INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, name, metadata, owner_id, tenant_id, visibility)
VALUES
  ('00000000-0000-4000-8000-0000000000aa', 0, 'manifest', 'bootstrap:terraform', 'defined', 'manifest', now(), 'active',
   'kernel_manifest',
   jsonb_build_object(
     'kernels', jsonb_build_object(
       'run_code', '00000000-0000-4000-8000-000000000001',
       'observer', '00000000-0000-4000-8000-000000000002',
       'request_worker', '00000000-0000-4000-8000-000000000003',
       'policy_agent', '00000000-0000-4000-8000-000000000004',
       'provider_exec', '00000000-0000-4000-8000-000000000005'
     ),
     'allowed_boot_ids', jsonb_build_array(
       '00000000-0000-4000-8000-000000000001',
       '00000000-0000-4000-8000-000000000002',
       '00000000-0000-4000-8000-000000000003',
       '00000000-0000-4000-8000-000000000004',
       '00000000-0000-4000-8000-000000000005'
     ),
     'throttle', jsonb_build_object('per_tenant_daily_exec_limit', 1000),
     'policy', jsonb_build_object('slow_ms', 5000),
     'version', '1.0.0'
   ),
   'bootstrap:terraform', 'voulezvous', 'tenant');

-- Verify
SELECT
  id,
  entity_type,
  name,
  metadata->>'version' as version,
  status
FROM ledger.universal_registry
WHERE entity_type = 'manifest';
