output "db_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "signing_key_secret_arn" {
  description = "ARN of the signing key secret"
  value       = aws_secretsmanager_secret.signing_key.arn
}

output "openai_api_key_secret_arn" {
  description = "ARN of the OpenAI API key secret"
  value       = var.openai_api_key != "" ? aws_secretsmanager_secret.openai_api_key[0].arn : ""
}

output "secrets_read_policy_arn" {
  description = "ARN of the IAM policy for reading secrets"
  value       = aws_iam_policy.lambda_secrets_read.arn
}
