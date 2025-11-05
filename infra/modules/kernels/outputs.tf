output "run_code_lambda_arn" {
  description = "ARN of the run_code Lambda function"
  value       = aws_lambda_function.kernel["run_code"].arn
}

output "run_code_lambda_name" {
  description = "Name of the run_code Lambda function"
  value       = aws_lambda_function.kernel["run_code"].function_name
}

output "observer_lambda_arn" {
  description = "ARN of the observer_bot Lambda function"
  value       = aws_lambda_function.kernel["observer_bot"].arn
}

output "observer_lambda_name" {
  description = "Name of the observer_bot Lambda function"
  value       = aws_lambda_function.kernel["observer_bot"].function_name
}

output "worker_lambda_arn" {
  description = "ARN of the request_worker Lambda function"
  value       = aws_lambda_function.kernel["request_worker"].arn
}

output "worker_lambda_name" {
  description = "Name of the request_worker Lambda function"
  value       = aws_lambda_function.kernel["request_worker"].function_name
}

output "policy_lambda_arn" {
  description = "ARN of the policy_agent Lambda function"
  value       = aws_lambda_function.kernel["policy_agent"].arn
}

output "policy_lambda_name" {
  description = "Name of the policy_agent Lambda function"
  value       = aws_lambda_function.kernel["policy_agent"].function_name
}

output "provider_lambda_arn" {
  description = "ARN of the provider_exec Lambda function"
  value       = aws_lambda_function.kernel["provider_exec"].arn
}

output "provider_lambda_name" {
  description = "Name of the provider_exec Lambda function"
  value       = aws_lambda_function.kernel["provider_exec"].function_name
}
