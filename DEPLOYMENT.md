# LogLine Deployment Guide

This guide walks you through deploying the complete LogLine OS infrastructure.

## Prerequisites

- AWS account with admin credentials
- AWS CLI configured (`aws configure`)
- Terraform 1.6+
- PostgreSQL 16 client (psql)
- Node.js 20+
- jq (for JSON parsing in tests)

## Quick Deploy (Automated)

The fastest way to deploy is using the master deployment script:

```bash
./DEPLOY_MASTER.sh
```

This script will:
1. Validate your environment
2. Generate credentials (if needed)
3. Install Node.js dependencies
4. Deploy all infrastructure with Terraform
5. Initialize the database schema
6. Seed kernel functions
7. Run tests

**Estimated time: 15-20 minutes**

## Manual Deployment (Step-by-Step)

If you prefer to control each step:

### 1. Validate Environment

```bash
./validate_deployment.sh
```

This checks that all required files and tools are present.

### 2. Generate Credentials

```bash
# Generate Ed25519 signing keys
./generate_keys.sh

# Generate secure database password
./generate_db_password.sh
```

Credentials are saved to:
- `keys/signing_keys.env`
- `keys/db_credentials.env`

### 3. Install Dependencies

```bash
# Stage-0 dependencies
cd src/stage0
npm install --production
cd ../..

# Kernel dependencies
cd src/kernels
npm install --production
cd ../..
```

### 4. Configure Terraform

```bash
cd infra

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Required variables:
- `aws_region`: Your AWS region (e.g., "us-east-1")
- `db_password`: From `keys/db_credentials.env`
- `signing_key_hex`: From `keys/signing_keys.env`

### 5. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
```

This creates:
- RDS PostgreSQL database
- VPC and networking
- Secrets Manager secrets
- Stage-0 Lambda function
- 5 kernel Lambda functions
- API Gateway
- EventBridge schedulers

### 6. Initialize Database

```bash
cd ..

# Run schema initialization
./deploy_logline.sh

# Seed kernel functions
./seed_kernels.sh
```

### 7. Verify Deployment

```bash
./test_deployment.sh
```

## What Gets Deployed

### Database Layer
- **RDS PostgreSQL 16** (db.t4g.micro)
- Multi-AZ for production
- Encrypted at rest
- Automated backups (7 days)
- Row-Level Security enabled

### Compute Layer
- **Stage-0 Lambda**: Bootstrap loader
- **run_code**: Execute code requests
- **observer_bot**: Monitor timeline (runs every 10s)
- **request_worker**: Process requests (runs every 10s)
- **policy_agent**: Enforce policies (runs every 30s)
- **provider_exec**: External integrations (on-demand)

### API Layer
- **API Gateway**: REST endpoints
  - `POST /api/spans` - Insert spans
  - `GET /api/timeline` - Query timeline
  - `GET /api/timeline/stream` - SSE stream (coming soon)

### Scheduler
- **EventBridge Rules**: Cron jobs for kernels
  - Observer: Every 10 seconds
  - Worker: Every 10 seconds
  - Policy: Every 30 seconds
  - Midnight Ruler: 00:00 Europe/Paris

## Post-Deployment

### Get Endpoints

```bash
cd infra
terraform output api_endpoint
terraform output database_endpoint
```

### Test the API

```bash
# Get API endpoint
API=$(cd infra && terraform output -raw api_endpoint)

# Query timeline
curl "$API/api/timeline?limit=5" | jq .

# Insert a test span
curl -X POST "$API/api/spans" \
  -H 'Content-Type: application/json' \
  -d '{
    "entity_type": "test",
    "who": "deployment_test",
    "this": "first_span",
    "metadata": {"deployed_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}
  }' | jq .
```

### Connect to Database

```bash
./connect_db.sh
```

Then run SQL queries:

```sql
-- View all spans
SELECT * FROM ledger.visible_timeline 
ORDER BY at DESC LIMIT 10;

-- Count by entity type
SELECT entity_type, COUNT(*) 
FROM ledger.universal_registry 
GROUP BY entity_type;

-- View kernel functions
SELECT id, name, status, runtime 
FROM ledger.universal_registry 
WHERE entity_type = 'function';
```

### View Logs

```bash
# Stage-0 logs
aws logs tail /aws/lambda/logline-dev-stage0 --follow

# Specific kernel logs
aws logs tail /aws/lambda/logline-dev-run_code --follow
aws logs tail /aws/lambda/logline-dev-observer_bot --follow
```

## Cost Estimate

### Development Environment
- RDS db.t4g.micro: ~$15/month
- Lambda (within free tier): ~$5/month
- API Gateway: ~$3/month
- Secrets Manager: ~$2/month
- CloudWatch Logs: ~$2/month

**Total: ~$27/month**

### Production Environment
- RDS db.t4g.medium (Multi-AZ): ~$120/month
- Lambda: ~$50/month
- API Gateway: ~$10/month
- NAT Gateway: ~$32/month

**Total: ~$212/month**

## Troubleshooting

### Terraform Errors

```bash
# Validate configuration
cd infra
terraform validate

# Format files
terraform fmt -recursive

# Refresh state
terraform refresh
```

### Database Connection Issues

```bash
# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*logline*"

# Test connection
./connect_db.sh
```

### Lambda Errors

```bash
# Check function configuration
aws lambda get-function --function-name logline-dev-stage0

# View recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/logline-dev-stage0 \
  --filter-pattern "ERROR"
```

## Cleanup

To destroy all infrastructure:

```bash
cd infra
terraform destroy
```

**Warning**: This will delete:
- All database data
- All Lambda functions
- All secrets
- All logs

Make sure to backup any important data first!

## Next Steps

1. **Configure Manifest**: Update the manifest to allow specific boot functions
2. **Add Custom Kernels**: Create your own kernel functions
3. **Enable SSE**: Implement Server-Sent Events for real-time updates
4. **Add Authentication**: Implement API key or JWT authentication
5. **Monitor**: Set up CloudWatch alarms and dashboards

## Support

For issues or questions:
- Check logs: `aws logs tail /aws/lambda/logline-dev-stage0`
- Review Terraform state: `terraform show`
- Run tests: `./test_deployment.sh`
- Check database: `./connect_db.sh`

## Security Best Practices

1. **Never commit credentials** to version control
2. **Rotate signing keys** regularly
3. **Enable MFA** on AWS account
4. **Review IAM policies** periodically
5. **Monitor CloudWatch** for anomalies
6. **Enable VPC Flow Logs** for network monitoring
7. **Use AWS Secrets Manager** for all sensitive data

---

Made with ❤️ and constitutional rigor
