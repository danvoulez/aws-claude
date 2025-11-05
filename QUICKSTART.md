# Quick Start Guide

Get LogLine database infrastructure running in 15 minutes.

## Prerequisites

- AWS Account with admin credentials
- AWS CLI v2+ configured
- Terraform 1.6+
- PostgreSQL client (psql)
- OpenSSL (for key generation)

## Step-by-Step

### 1. Verify Prerequisites

```bash
# Check installations
aws --version        # Should show v2.x
terraform version    # Should show >= 1.6
psql --version      # Should show >= 14
openssl version     # Any recent version

# Verify AWS credentials
aws sts get-caller-identity
```

### 2. Generate Security Keys

```bash
# Generate Ed25519 signing keys
./generate_keys.sh

# Generate secure database password
./generate_db_password.sh
```

This creates:
- `keys/private.pem` - Your private signing key (BACKUP THIS!)
- `keys/public.pem` - Your public key
- `keys/signing_keys.env` - Hex-encoded keys
- `keys/db_credentials.env` - Database password

⚠️ **IMPORTANT**: Backup the `keys/` directory to a secure location!

### 3. Configure Terraform

```bash
cd infra

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
nano terraform.tfvars
```

Required changes in `terraform.tfvars`:
```hcl
aws_region  = "us-east-1"  # Your preferred region
db_password = "PASTE_PASSWORD_FROM_keys/db_credentials.env"
```

### 4. Deploy Database

```bash
# Initialize Terraform
terraform init

# Preview what will be created
terraform plan -target=module.database

# Deploy (takes 5-10 minutes)
terraform apply -target=module.database

# Type 'yes' when prompted
```

### 5. Initialize Schema

```bash
# Get connection string
CONNECTION_STRING=$(terraform output -raw connection_string)

# Initialize database schema
psql "$CONNECTION_STRING" < scripts/init_db.sql

# Seed manifest
psql "$CONNECTION_STRING" < scripts/seed_manifest.sql

# Seed kernel functions
psql "$CONNECTION_STRING" < scripts/seed_kernels.sql
```

### 6. Verify Deployment

```bash
# Connect to database
./connect_db.sh

# Or manually
psql "$CONNECTION_STRING"
```

In psql:
```sql
-- List tables
\dt ledger.*

-- Check manifest
SELECT * FROM ledger.universal_registry WHERE entity_type = 'manifest';

-- Check kernels
SELECT id, name, description FROM ledger.universal_registry 
WHERE entity_type = 'function' ORDER BY id;

-- Test insert
SET app.user_id = 'test@example.com';
SET app.tenant_id = 'voulezvous';

INSERT INTO ledger.universal_registry
  (id, seq, entity_type, who, did, "this", status, owner_id, tenant_id, visibility)
VALUES
  (gen_random_uuid(), 0, 'test', 'test@example.com', 'tested', 'quickstart', 
   'complete', 'test@example.com', 'voulezvous', 'private');

-- Verify
SELECT * FROM ledger.visible_timeline WHERE entity_type = 'test';
```

## What You Just Deployed

✅ **RDS PostgreSQL 16**
- Instance: db.t4g.micro
- Storage: 20GB (auto-scales to 100GB)
- Encrypted at rest
- Automated backups (7 days)
- Multi-AZ ready

✅ **LogLine Schema**
- Universal registry table
- Row-level security (RLS)
- Append-only enforcement
- SSE notification triggers
- Optimized indexes

✅ **Security**
- Private VPC deployment
- Security groups configured
- Ed25519 key pair generated
- Credentials secured

## Monthly Cost

Current deployment: **~$15/month**
- RDS db.t4g.micro: ~$13/month
- Storage: ~$2/month
- Backups (7 days): included

## Next Steps

### Option A: Use the Database Directly
```bash
# Connect and start working
./connect_db.sh

# Query spans
SELECT * FROM ledger.visible_timeline ORDER BY at DESC LIMIT 10;

# Insert spans
INSERT INTO ledger.universal_registry (...) VALUES (...);
```

### Option B: Deploy Remaining Phases

See `IMPLEMENTATION_STATUS.md` for:
- Phase 2: Stage-0 Lambda
- Phase 3: API Gateway
- Phase 4: Kernel Lambdas
- Phase 5: EventBridge Scheduler
- Phase 6: Secrets Manager

Each phase adds more capabilities but Phase 1 gives you a working ledger.

## Troubleshooting

### RDS Not Available
```bash
# Check status
cd infra
aws rds describe-db-instances \
  --db-instance-identifier logline-dev-db \
  --query 'DBInstances[0].DBInstanceStatus'

# Wait until "available"
```

### Connection Refused
```bash
# Check security groups
cd infra
terraform output database_security_group_id

# Verify your IP is allowed (if needed)
# Edit terraform.tfvars and add:
# db_allowed_cidr_blocks = ["YOUR_IP/32"]
# Then: terraform apply -target=module.database
```

### Schema Errors
```bash
# Re-run initialization
cd infra
psql "$(terraform output -raw connection_string)" < scripts/init_db.sql
```

## Cleanup

To destroy everything:
```bash
cd infra
terraform destroy -target=module.database

# Type 'yes' when prompted
```

⚠️ This deletes all data unless you have a final snapshot enabled.

## Support

- Review `README.md` for detailed documentation
- Check `IMPLEMENTATION_STATUS.md` for what's implemented
- See `PLAN.MD` for complete architecture specification

## Success!

You now have a production-ready LogLine ledger system running on AWS! 🎉

The database is ready to:
- Store immutable spans
- Enforce row-level security
- Provide append-only guarantees
- Send real-time notifications
- Scale to millions of records

Start inserting spans and building your constitutional operating system.
