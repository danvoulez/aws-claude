output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.db_endpoint
}

output "database_name" {
  description = "Name of the database"
  value       = module.database.db_name
}

output "database_port" {
  description = "Database port"
  value       = module.database.db_port
}

output "database_security_group_id" {
  description = "Security group ID for database access"
  value       = module.database.db_security_group_id
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = module.database.connection_string
  sensitive   = true
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api.api_endpoint
}

output "stage0_function_name" {
  description = "Stage-0 Lambda function name"
  value       = module.stage0.stage0_function_name
}

output "run_code_function_name" {
  description = "run_code Lambda function name"
  value       = module.kernels.run_code_lambda_name
}

output "observer_function_name" {
  description = "observer_bot Lambda function name"
  value       = module.kernels.observer_lambda_name
}

output "request_worker_function_name" {
  description = "request_worker Lambda function name"
  value       = module.kernels.request_worker_lambda_name
}

output "policy_agent_function_name" {
  description = "policy_agent Lambda function name"
  value       = module.kernels.policy_agent_lambda_name
}

output "provider_exec_function_name" {
  description = "provider_exec Lambda function name"
  value       = module.kernels.provider_exec_lambda_name
}
