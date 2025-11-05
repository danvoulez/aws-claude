output "stage0_function_arn" {
  description = "ARN of the Stage-0 Lambda function"
  value       = aws_lambda_function.stage0.arn
}

output "stage0_function_name" {
  description = "Name of the Stage-0 Lambda function"
  value       = aws_lambda_function.stage0.function_name
}

output "stage0_invoke_arn" {
  description = "Invoke ARN of the Stage-0 Lambda function"
  value       = aws_lambda_function.stage0.invoke_arn
}
