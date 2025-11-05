terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Store state in S3 (recommended for production)
  # backend "s3" {
  #   bucket = "logline-terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "LogLine"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# VPC - Use default VPC for simplicity (or create custom VPC)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Secrets Module
module "secrets" {
  source = "./modules/secrets"

  project_name    = var.project_name
  environment     = var.environment
  db_password     = var.db_password
  signing_key_hex = var.signing_key_hex
  public_key_hex  = var.public_key_hex
  openai_api_key  = var.openai_api_key
}

# Database Module
module "database" {
  source = "./modules/database"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = data.aws_vpc.default.id
  subnet_ids         = data.aws_subnets.default.ids

  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password

  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  multi_az           = var.db_multi_az

  backup_retention_period = var.db_backup_retention_period
  backup_window          = var.db_backup_window
  maintenance_window     = var.db_maintenance_window

  allowed_cidr_blocks = var.db_allowed_cidr_blocks
}

# Stage-0 Module
module "stage0" {
  source = "./modules/stage0"

  project_name              = var.project_name
  environment               = var.environment
  subnet_ids                = data.aws_subnets.default.ids
  lambda_security_group_id  = module.database.lambda_security_group_id
  database_url              = module.database.connection_string
  app_tenant_id             = var.app_tenant_id
  signing_key_hex           = var.signing_key_hex
  secrets_read_policy_arn   = module.secrets.secrets_read_policy_arn

  depends_on = [module.database, module.secrets]
}

# Kernels Module
module "kernels" {
  source = "./modules/kernels"

  project_name              = var.project_name
  environment               = var.environment
  subnet_ids                = data.aws_subnets.default.ids
  lambda_security_group_id  = module.database.lambda_security_group_id
  database_url              = module.database.connection_string
  app_tenant_id             = var.app_tenant_id
  signing_key_hex           = var.signing_key_hex
  secrets_read_policy_arn   = module.secrets.secrets_read_policy_arn

  depends_on = [module.database, module.secrets]
}

# API Gateway Module
module "api" {
  source = "./modules/api"

  project_name              = var.project_name
  environment               = var.environment
  stage0_lambda_invoke_arn  = module.stage0.stage0_invoke_arn
  stage0_lambda_name        = module.stage0.stage0_function_name

  depends_on = [module.stage0]
}

# Scheduler Module
module "scheduler" {
  source = "./modules/scheduler"

  project_name           = var.project_name
  environment            = var.environment
  observer_lambda_arn    = module.kernels.observer_lambda_arn
  observer_lambda_name   = module.kernels.observer_lambda_name
  worker_lambda_arn      = module.kernels.request_worker_lambda_arn
  worker_lambda_name     = module.kernels.request_worker_lambda_name
  policy_lambda_arn      = module.kernels.policy_agent_lambda_arn
  policy_lambda_name     = module.kernels.policy_agent_lambda_name
  run_code_lambda_arn    = module.kernels.run_code_lambda_arn
  run_code_lambda_name   = module.kernels.run_code_lambda_name

  depends_on = [module.kernels]
}
