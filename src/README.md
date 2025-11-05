# LogLine Source Code

This directory contains the Lambda function implementations for LogLine OS.

## Structure

```
src/
├── stage0/          # Bootstrap loader (Stage-0)
│   ├── db.js        # Shared database utilities
│   ├── index.js     # Main handler
│   └── package.json # Dependencies
│
└── kernels/         # Core kernel functions
    ├── db.js        # Shared database utilities
    ├── package.json # Dependencies
    │
    ├── run_code/    # Kernel 1: Code execution
    ├── observer_bot/# Kernel 2: Status monitoring
    ├── request_worker/ # Kernel 3: Request processing
    ├── policy_agent/   # Kernel 4: Policy evaluation
    └── provider_exec/  # Kernel 5: External API calls
```

## Stage-0 Bootstrap Loader

Stage-0 is the only code that runs outside the ledger. It:

1. **Validates** boot function ID against manifest allowlist
2. **Fetches** the function code from the ledger
3. **Verifies** cryptographic signature
4. **Executes** the function with minimal, sandboxed context
5. **Emits** boot event span to the ledger

### API Endpoints

Stage-0 handles these HTTP endpoints:

- `GET /api/timeline` - Query spans with filtering
- `POST /api/spans` - Insert new spans
- `POST /execute` - Execute a boot function

### Context Provided to Kernels

```javascript
{
  env: { APP_USER_ID, APP_TENANT_ID, SIGNING_KEY_HEX },
  sql: async (strings, ...values) => { ... },
  insertSpan: async (span) => { ... },
  signSpan: async (span) => { ... },
  now: () => new Date().toISOString(),
  crypto: { blake3, ed25519, hex, toU8, randomUUID }
}
```

## Core Kernels

All kernels share the same database utilities (`db.js`) and export a `main` function:

```javascript
export async function main(ctx) {
  const { sql, insertSpan, now, crypto } = ctx;
  // Kernel-specific logic here
  return { success: true };
}
```

### 1. run_code (00000000-0000-4000-8000-000000000001)

Executes user-defined functions with:
- Advisory lock per span.id (prevents duplicates)
- Tenant-level quota enforcement
- Timeout detection
- Slow execution alerts

### 2. observer_bot (00000000-0000-4000-8000-000000000002)

Monitors for `status='scheduled'` spans:
- Runs every 10 seconds (EventBridge)
- Emits idempotent request spans
- Quota-aware
- Lock-based concurrency control

### 3. request_worker (00000000-0000-4000-8000-000000000003)

Processes request spans:
- Runs every 10 seconds (EventBridge)
- FIFO processing
- Loads target kernel from ledger
- Advisory lock on parent_id

### 4. policy_agent (00000000-0000-4000-8000-000000000004)

Evaluates active policies:
- Runs every 30 seconds (EventBridge)
- Cursor-based resumption
- Sandboxed evaluation (3s timeout)
- Emits action spans

### 5. provider_exec (00000000-0000-4000-8000-000000000005)

Calls external APIs:
- Multi-provider support (OpenAI, Ollama, custom)
- API key management from Secrets Manager
- Response logging

## Database Module (`db.js`)

Shared utilities used by both Stage-0 and kernels:

### Connection Management

```javascript
withPg(async (client) => {
  // Use client here
  // Automatically sets app.user_id and app.tenant_id
})
```

### Safe SQL Queries

```javascript
const sqlQuery = sql(client);
await sqlQuery`SELECT * FROM ledger.visible_timeline WHERE id=${id}`;
// Uses parameterized queries - SQL injection impossible
```

### Span Operations

```javascript
// Insert span (auto-signs if SIGNING_KEY_HEX is set)
const inserted = await insertSpan({
  id: crypto.randomUUID(),
  entity_type: 'execution',
  who: 'user@example.com',
  this: 'function',
  ...
});

// Sign span manually
await signSpan(span);  // Adds curr_hash, signature, public_key

// Verify span
await verifySpan(span);  // Throws if hash or signature invalid
```

### Cryptographic Utilities

```javascript
hex(uint8Array)      // Convert Uint8Array to hex string
toU8(hexString)      // Convert hex string to Uint8Array
now()                // Get ISO-8601 timestamp
```

## Dependencies

All Lambda functions require:

```json
{
  "pg": "^8.11.3",                // PostgreSQL client
  "@noble/hashes": "^1.3.3",      // BLAKE3 hashing
  "@noble/ed25519": "^2.0.0"      // Ed25519 signatures
}
```

## Environment Variables

### Stage-0 Lambda

- `DATABASE_URL` - PostgreSQL connection string
- `APP_USER_ID` - Default user ID (e.g., 'edge:stage0')
- `APP_TENANT_ID` - Default tenant ID (e.g., 'voulezvous')
- `SIGNING_KEY_HEX` - Ed25519 private key (hex-encoded)
- `BOOT_FUNCTION_ID` - Default boot function ID (optional)
- `NODE_ENV` - Environment (production/development)

### Kernel Lambdas

Same as Stage-0, plus:
- `KERNEL_ID` - Specific kernel UUID

## Security

### Cryptographic Signing

Every span can be signed with Ed25519:

1. Compute canonical JSON (sorted keys)
2. Hash with BLAKE3 → `curr_hash`
3. Sign hash with private key → `signature`
4. Include public key → `public_key`

Verification:
1. Recompute canonical JSON
2. Hash and compare with `curr_hash`
3. Verify `signature` with `public_key`

### Database Security

- **Row-Level Security (RLS)**: Enforced by PostgreSQL
- **Append-only**: Trigger blocks UPDATE/DELETE
- **Session variables**: `app.user_id` and `app.tenant_id` set per connection
- **Parameterized queries**: No SQL injection possible

### Sandboxing

Kernels execute in Lambda with:
- No network access (except to RDS via VPC)
- Read-only code from ledger
- Limited memory/timeout
- No file system write

## Development

### Local Testing

```bash
# Install dependencies
cd src/stage0 && npm install
cd ../kernels && npm install

# Set environment variables
export DATABASE_URL="postgresql://user:pass@localhost:5432/logline"
export APP_USER_ID="local:dev"
export SIGNING_KEY_HEX="your_key_here"

# Run Stage-0 locally (Node.js)
node -e "import('./stage0/index.js').then(m => m.handler({}))"
```

### Deployment

Lambda functions are packaged and deployed by Terraform:

```bash
cd infra
terraform apply -target=module.stage0
terraform apply -target=module.kernels
```

Terraform creates ZIP archives from `src/stage0/` and `src/kernels/` and deploys them as Lambda functions.

## Architecture

```
┌─────────────────────────────────────┐
│ API Gateway                         │
├─────────────────────────────────────┤
│ /api/timeline  → Stage-0 (query)    │
│ /api/spans     → Stage-0 (insert)   │
│ /execute       → Stage-0 (boot)     │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Stage-0 Lambda                      │
├─────────────────────────────────────┤
│ 1. Validate manifest allowlist      │
│ 2. Fetch function from ledger       │
│ 3. Verify signature                 │
│ 4. Execute with context             │
│ 5. Emit boot event                  │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Kernel Lambdas                      │
├─────────────────────────────────────┤
│ run_code      (on-demand)           │
│ observer_bot  (every 10s)           │
│ request_worker(every 10s)           │
│ policy_agent  (every 30s)           │
│ provider_exec (on-demand)           │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ RDS PostgreSQL                      │
├─────────────────────────────────────┤
│ ledger.universal_registry           │
│ - Append-only                       │
│ - RLS enabled                       │
│ - Cryptographically signed          │
└─────────────────────────────────────┘
```

## License

MIT License - See main README for details
