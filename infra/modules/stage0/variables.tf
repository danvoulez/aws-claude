variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "boot_function_id" {
  description = "UUID of the boot function to load"
  type        = string
  default     = "00000000-0000-4000-8000-000000000001"
}

variable "app_user_id" {
  description = "Application user ID"
  type        = string
  default     = "edge:stage0"
}

variable "app_tenant_id" {
  description = "Application tenant ID"
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
}
