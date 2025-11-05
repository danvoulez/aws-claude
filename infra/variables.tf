variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "logline"
}

# Database Variables
variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "logline"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "logline_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"  # Start small: ~$15/month
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false  # Set to true for production
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "db_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the database"
  type        = list(string)
  default     = []  # Lambda functions will use security groups
}

# Cryptographic Keys
variable "signing_key_hex" {
  description = "Ed25519 signing key in hex format"
  type        = string
  sensitive   = true
}

variable "public_key_hex" {
  description = "Ed25519 public key in hex format"
  type        = string
  sensitive   = false
}

# Application Configuration
variable "app_tenant_id" {
  description = "Application tenant ID"
  type        = string
  default     = "voulezvous"
}

variable "openai_api_key" {
  description = "OpenAI API key (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
