variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda deployment"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "database_url" {
  description = "Database connection URL"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Tenant ID"
  type        = string
  default     = "voulezvous"
}

variable "signing_key_hex" {
  description = "Ed25519 signing key in hex format"
  type        = string
  sensitive   = true
}

variable "secrets_read_policy_arn" {
  description = "ARN of the IAM policy for reading secrets"
  type        = string
  default     = ""
}
