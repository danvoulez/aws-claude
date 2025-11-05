variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "ingest_lambda_arn" {
  description = "ARN of the ingest Lambda function"
  type        = string
  default     = ""
}

variable "sse_lambda_arn" {
  description = "ARN of the SSE Lambda function"
  type        = string
  default     = ""
}
