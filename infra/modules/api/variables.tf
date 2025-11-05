variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "stage0_lambda_invoke_arn" {
  description = "Invoke ARN of the Stage-0 Lambda function"
  type        = string
}

variable "stage0_lambda_name" {
  description = "Name of the Stage-0 Lambda function"
  type        = string
}
