# LogLine - Constitutional Operating System

LogLine is a constitutional governance platform built on three inseparable principles:

1. **RESPONSIBILITY** - "You made a contract, you gotta do it."
2. **PRIVACY** - "You are important."
3. **ACCOUNTABILITY** - "Consequences."

## 🚀 Quick Start (5 Minutes)

### One-Command Deployment

```bash
# 1. Generate cryptographic keys
./generate_keys.sh

# 2. Generate database password
./generate_db_password.sh

# 3. Configure Terraform
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your keys and password
cd ..

# 4. Validate everything
./validate_deployment.sh

# 5. Deploy everything (15-20 minutes)
./DEPLOY_MASTER.sh

# 6. Run tests
./test_deployment.sh
```

That's it! Your LogLine system is now live with:
- ✅ PostgreSQL database with schema
- ✅ 5 kernel Lambda functions
- ✅ API Gateway endpoints
- ✅ EventBridge schedulers
- ✅ Cryptographic signing

### Quick Tests

```bash
# Query the timeline
curl "https://your-api-endpoint/api/timeline?limit=5" | jq .

# Insert a test span
curl -X POST "https://your-api-endpoint/api/spans" \
  -H 'Content-Type: application/json' \
  -d '{"entity_type":"test","who":"cli","this":"test"}'

# View Lambda logs
./tail_logs.sh stage0
```

---

## Detailed Setup Guide

### Prerequisites

- AWS account with admin credentials
- Terraform 1.6+
- PostgreSQL 16 client (psql)
- Node.js 20+
- 20 minutes

### Deployment Steps

#### 1. Install Dependencies

```bash
# Verify installations
terraform version  # >= 1.6
aws --version      # >= 2.0
psql --version     # >= 16
node --version     # >= 20
```

#### 2. Configure AWS

```bash
aws configure
# Enter your AWS Access Key ID, Secret Key, and Region
```

Test connection:
```bash
aws sts get-caller-identity
```

#### 3. Setup Terraform Variables

```bash
cd infra

# Copy example vars
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Set a strong database password:
```bash
# Generate a secure password
openssl rand -base64 32
```

#### 4. Deploy Database

```bash
cd infra

# Initialize Terraform
terraform init

# Preview changes
terraform plan -target=module.database

# Deploy the database (takes 5-10 minutes)
terraform apply -target=module.database
```

#### 5. Initialize Schema

```bash
# Get connection details
terraform output connection_string

# Initialize the database schema
psql "$(terraform output -raw connection_string)" < scripts/init_db.sql

# Seed the manifest
psql "$(terraform output -raw connection_string)" < scripts/seed_manifest.sql
```

#### 6. Verify Deployment

Connect to the database:
```bash
psql "$(terraform output -raw connection_string)"
```

Check the schema:
```sql
-- List tables
\dt ledger.*

-- Verify manifest
SELECT * FROM ledger.universal_registry WHERE entity_type = 'manifest';

-- Test insert
SET app.user_id = 'test@example.com';
SET app.tenant_id = 'voulezvous';

INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", at, status, owner_id, tenant_id, visibility)
VALUES
  (gen_random_uuid(), 0, 'test', 'test@example.com', 'tested', 'database', now(), 'complete', 'test@example.com', 'voulezvous', 'private');

-- Verify
SELECT * FROM ledger.visible_timeline WHERE entity_type = 'test';
```

## Infrastructure Overview

### What You Get

✅ **Production-ready RDS PostgreSQL**
- Encrypted at rest
- Automated backups (7 days)
- CloudWatch logging
- Security groups configured
- Auto-scaling storage

✅ **LogLine Schema Deployed**
- Universal registry table
- RLS enabled
- Append-only enforced
- SSE notifications ready
- Indexes optimized

✅ **Infrastructure as Code**
- Version controlled
- Repeatable deployments
- Easy to destroy/recreate

### Architecture

```
┌─────────────────────────────────────────────────────┐
│ AWS Infrastructure (Terraform)                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐    ┌──────────────────┐      │
│  │ RDS Postgres    │◄───│ Lambda Stage-0   │      │
│  │ (Ledger)        │    │ (Bootstrap)      │      │
│  │ - Multi-AZ      │    └──────────────────┘      │
│  │ - Encrypted     │              ▲                │
│  │ - WAL archival  │              │                │
│  └─────────────────┘              │                │
│         ▲                          │                │
│         │                          │                │
│  ┌──────┴──────────────────────────┴─────┐        │
│  │ API Gateway (REST + WebSocket)        │        │
│  │ - /api/spans                          │        │
│  │ - /api/timeline/stream (SSE)          │        │
│  │ - /manifest/*                         │        │
│  └───────────────────────────────────────┘        │
│         ▲                                          │
│         │                                          │
│  ┌──────┴────────────────────────────────┐        │
│  │ Lambda Functions (Kernels)            │        │
│  │ - run_code_kernel                     │        │
│  │ - observer_bot_kernel                 │        │
│  │ - request_worker_kernel               │        │
│  │ - policy_agent_kernel                 │        │
│  │ - provider_exec_kernel                │        │
│  └───────────────────────────────────────┘        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Cost Estimate

### Development (minimal load)
- RDS db.t4g.micro: ~$15/month
- Lambda (within free tier): ~$5/month
- API Gateway: ~$3/month
- Secrets Manager: ~$2/month
- CloudWatch Logs: ~$2/month

**Total: ~$27/month**

### Production (100K executions/day)
- RDS db.t4g.medium (Multi-AZ): ~$120/month
- Lambda: ~$50/month
- API Gateway: ~$10/month
- NAT Gateway: ~$32/month

**Total: ~$212/month**

## Directory Structure

```
infra/
├── main.tf                 # Root module
├── variables.tf            # Input variables
├── outputs.tf              # Outputs (API endpoints, etc)
├── terraform.tfvars        # Your specific values (gitignored)
│
├── modules/
│   ├── database/
│   │   ├── main.tf         # RDS Postgres
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── security.tf
│   │
│   ├── stage0/
│   │   ├── main.tf         # Stage-0 Lambda + Layer
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── kernels/
│   │   ├── main.tf         # All kernel Lambdas
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── api/
│   │   ├── main.tf         # API Gateway
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── scheduler/
│   │   ├── main.tf         # EventBridge rules
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── secrets/
│       ├── main.tf         # Secrets Manager
│       ├── variables.tf
│       └── outputs.tf
│
└── scripts/
    ├── init_db.sql         # Schema bootstrap
    └── seed_manifest.sql   # Insert kernel spans
```

## Database Schema

The Universal Registry stores all governable entities:

```sql
CREATE TABLE ledger.universal_registry (
  -- Core identity
  id            uuid        NOT NULL,
  seq           integer     NOT NULL DEFAULT 0,
  entity_type   text        NOT NULL,
  who           text        NOT NULL,
  did           text,
  "this"        text        NOT NULL,
  at            timestamptz NOT NULL DEFAULT now(),

  -- Relationships
  parent_id     uuid,
  related_to    uuid[],

  -- Access control
  owner_id      text,
  tenant_id     text,
  visibility    text        NOT NULL DEFAULT 'private',

  -- Lifecycle
  status        text,
  is_deleted    boolean     NOT NULL DEFAULT false,

  -- Code & Execution
  name          text,
  description   text,
  code          text,
  language      text,
  runtime       text,
  input         jsonb,
  output        jsonb,
  error         jsonb,

  -- Content (memory, prompts)
  content       jsonb,

  -- Metrics
  duration_ms   integer,
  trace_id      text,

  -- Crypto
  prev_hash     text,
  curr_hash     text,
  signature     text,
  public_key    text,

  -- Extensibility
  metadata      jsonb,

  PRIMARY KEY (id, seq)
);
```

## Security Features

- **Row-Level Security (RLS)** - Database-enforced access control
- **Append-only ledger** - No UPDATE or DELETE allowed
- **Cryptographic signatures** - Ed25519 signed spans
- **Private by default** - Explicit consent required for sharing
- **VPC isolation** - Lambdas and RDS in private subnets

## Next Steps

After database deployment, you can add:

- **Stage-0 Lambda** - Bootstrap loader
- **API Gateway** - HTTP endpoints
- **Kernel Lambdas** - run_code, observer, worker, policy, provider
- **EventBridge Scheduler** - Cron jobs for midnight ruler

See `PLAN.MD` for complete specifications.

## Support

For questions or issues:
- Review `PLAN.MD` for detailed architecture
- Check AWS CloudWatch logs for debugging
- Review Terraform state: `terraform show`

## License

MIT License - See PLAN.MD for full details

---

Made with ❤️ and constitutional rigor
