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

variable "db_host" {
  description = "Database hostname"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "boot_function_id" {
  description = "UUID of the boot function to load"
  type        = string
  default     = "00000000-0000-4000-8000-000000000001"
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
