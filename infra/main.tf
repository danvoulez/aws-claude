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
