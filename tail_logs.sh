#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Check if function name provided
if [ -z "$1" ]; then
  echo "Usage: ./tail_logs.sh <function_name>"
  echo ""
  echo "Available functions:"
  echo "  stage0          - Stage-0 bootstrap loader"
  echo "  run_code        - run_code kernel"
  echo "  observer        - observer_bot kernel"
  echo "  request_worker  - request_worker kernel"
  echo "  policy          - policy_agent kernel"
  echo "  provider        - provider_exec kernel"
  echo "  all             - All Lambda functions (multiplexed)"
  exit 1
fi

# Get project name and environment from Terraform
cd infra 2>/dev/null || { echo "Error: infra directory not found"; exit 1; }
PROJECT_NAME=$(terraform output -raw stage0_function_name 2>/dev/null | cut -d'-' -f1 || echo "logline")
ENVIRONMENT=$(terraform output -raw stage0_function_name 2>/dev/null | cut -d'-' -f2 || echo "dev")
cd ..

# Map function aliases to full names
case "$1" in
  stage0)
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-stage0"
    ;;
  run_code)
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-run_code"
    ;;
  observer)
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-observer_bot"
    ;;
  request_worker|worker)
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-request_worker"
    ;;
  policy)
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-policy_agent"
    ;;
  provider)
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-provider_exec"
    ;;
  all)
    log_info "Tailing all Lambda functions..."
    echo ""
    ./tail_logs.sh stage0 &
    ./tail_logs.sh run_code &
    ./tail_logs.sh observer &
    ./tail_logs.sh request_worker &
    ./tail_logs.sh policy &
    ./tail_logs.sh provider &
    wait
    exit 0
    ;;
  *)
    # Assume it's a full function name
    FUNCTION_NAME="$1"
    ;;
esac

LOG_GROUP="/aws/lambda/${FUNCTION_NAME}"

log_info "Tailing logs for: $FUNCTION_NAME"
log_info "Log Group: $LOG_GROUP"
echo ""

# Check if log group exists
if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" 2>/dev/null | grep -q "$LOG_GROUP"; then
  echo "Warning: Log group $LOG_GROUP not found"
  echo "The function may not have been invoked yet, or it doesn't exist."
  echo ""
  echo "Creating log stream watcher anyway..."
fi

# Tail the logs
aws logs tail "$LOG_GROUP" --follow --format short
