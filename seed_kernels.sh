#!/bin/bash
set -e

echo "🌱 Seeding Kernel Functions"
echo "============================"
echo ""

# Check if we're in the right directory
if [ ! -f "infra/scripts/seed_kernels.sql" ]; then
  echo "Error: seed_kernels.sql not found. Run this script from the repository root."
  exit 1
fi

# Check if database connection info is available
cd infra
if ! terraform output -raw database_endpoint &> /dev/null; then
  echo "Error: Database not deployed. Run ./deploy_logline.sh first."
  exit 1
fi

CONNECTION_STRING=$(terraform output -raw connection_string)
cd ..

echo "📝 Running kernel seed script..."
psql "$CONNECTION_STRING" < infra/scripts/seed_kernels.sql

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Kernel functions seeded successfully!"
  echo ""
  echo "Verifying kernels in database..."
  psql "$CONNECTION_STRING" -c "
    SELECT id, name, language, runtime, status 
    FROM ledger.universal_registry 
    WHERE entity_type='function' 
    ORDER BY name;
  "
else
  echo ""
  echo "❌ Failed to seed kernels"
  exit 1
fi
