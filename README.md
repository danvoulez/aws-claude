# LogLine - Constitutional Operating System

LogLine is a constitutional governance platform built on three inseparable principles:

1. **RESPONSIBILITY** - "You made a contract, you gotta do it."
2. **PRIVACY** - "You are important."
3. **ACCOUNTABILITY** - "Consequences."

## Quick Start

### Prerequisites

- AWS account with admin credentials
- Terraform 1.6+
- PostgreSQL 16 client (psql)
- Node.js 20+
- 20 minutes

### One-Command Deployment (Recommended)

For automated deployment with all prerequisites checked:

```bash
# Clone the repository
git clone https://github.com/danvoulez/aws-claude.git
cd aws-claude

# Configure AWS credentials first
aws configure

# Run master deployment (validates, generates keys, deploys, tests)
./DEPLOY_MASTER.sh
```

This script will:
1. ✅ Validate your environment and dependencies
2. ✅ Generate Ed25519 cryptographic keys
3. ✅ Generate a secure database password
4. ✅ Create `terraform.tfvars` with sensible defaults
5. ✅ Deploy all infrastructure (database, lambdas, API, scheduler)
6. ✅ Initialize the database schema
7. ✅ Seed kernel functions
8. ✅ Run deployment tests

Total time: ~15-20 minutes

### Manual Deployment Steps

If you prefer manual control over each step:

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

## Utility Scripts

The repository includes several helper scripts for deployment and management:

### Deployment Scripts

- **`./DEPLOY_MASTER.sh`** - One-command full deployment
  - Validates environment
  - Generates keys and credentials
  - Deploys infrastructure
  - Seeds database
  - Runs tests

- **`./validate_deployment.sh`** - Pre-deployment validation
  - Checks file structure
  - Verifies AWS credentials
  - Validates Terraform configuration
  - Checks Node.js dependencies

- **`./deploy_logline.sh`** - Infrastructure deployment
  - Deploys database
  - Deploys Lambda functions
  - Deploys API Gateway
  - Initializes schema

- **`./seed_kernels.sh`** - Seed kernel functions
  - Inserts 5 core kernel spans into ledger
  - Verifies seeding success

- **`./test_deployment.sh`** - Post-deployment tests
  - Tests database connectivity
  - Verifies schema integrity
  - Checks kernel seeding
  - Validates manifest

### Key Generation Scripts

- **`./generate_keys.sh`** - Generate Ed25519 key pair
  - Creates `keys/private.pem`
  - Creates `keys/public.pem`
  - Creates `keys/signing_keys.env` (hex-encoded)

- **`./generate_db_password.sh`** - Generate secure database password
  - Creates `keys/db_credentials.env`
  - Uses cryptographically secure random generation

### Connection Scripts

- **`./connect_db.sh`** - Connect to deployed database
  - Opens psql session
  - Sets session variables automatically

All scripts are executable and documented with inline comments.

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
