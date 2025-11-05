variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "observer_lambda_arn" {
  description = "ARN of the observer_bot Lambda function"
  type        = string
  default     = ""
}

variable "observer_lambda_name" {
  description = "Name of the observer_bot Lambda function"
  type        = string
  default     = ""
}

variable "worker_lambda_arn" {
  description = "ARN of the request_worker Lambda function"
  type        = string
  default     = ""
}

variable "worker_lambda_name" {
  description = "Name of the request_worker Lambda function"
  type        = string
  default     = ""
}

variable "policy_lambda_arn" {
  description = "ARN of the policy_agent Lambda function"
  type        = string
  default     = ""
}

variable "policy_lambda_name" {
  description = "Name of the policy_agent Lambda function"
  type        = string
  default     = ""
}

variable "run_code_lambda_arn" {
  description = "ARN of the run_code Lambda function (for midnight ruler)"
  type        = string
  default     = ""
}

variable "run_code_lambda_name" {
  description = "Name of the run_code Lambda function"
  type        = string
  default     = ""
}
