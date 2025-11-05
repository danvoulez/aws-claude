# IAM policy for Lambdas to read secrets
resource "aws_iam_policy" "lambda_secrets_read" {
  name        = "${var.project_name}-${var.environment}-lambda-secrets-read"
  description = "Allow Lambdas to read secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.signing_key.arn,
          "${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

data "aws_region" "current" {}

output "secrets_read_policy_arn" {
  description = "ARN of the secrets read policy"
  value       = aws_iam_policy.lambda_secrets_read.arn
}
