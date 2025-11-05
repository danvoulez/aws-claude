# Secrets Manager Module
# Purpose: Store and manage sensitive credentials

# Database password secret
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}-${var.environment}-db-password"
  description = "RDS PostgreSQL master password"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# Signing key secret
resource "aws_secretsmanager_secret" "signing_key" {
  name        = "${var.project_name}-${var.environment}-signing-key"
  description = "Ed25519 signing key for span signatures"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-signing-key"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "signing_key" {
  secret_id     = aws_secretsmanager_secret.signing_key.id
  secret_string = var.signing_key_hex
}

# OpenAI API key secret (optional)
resource "aws_secretsmanager_secret" "openai_api_key" {
  count = var.openai_api_key != "" ? 1 : 0
  
  name        = "${var.project_name}-${var.environment}-openai-api-key"
  description = "OpenAI API key for provider integrations"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-openai-api-key"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  count = var.openai_api_key != "" ? 1 : 0
  
  secret_id     = aws_secretsmanager_secret.openai_api_key[0].id
  secret_string = var.openai_api_key
}

# IAM policy for Lambda functions to read secrets
resource "aws_iam_policy" "lambda_secrets_read" {
  name        = "${var.project_name}-${var.environment}-lambda-secrets-read"
  description = "Allow Lambda functions to read secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = concat(
          [
            aws_secretsmanager_secret.db_password.arn,
            aws_secretsmanager_secret.signing_key.arn
          ],
          var.openai_api_key != "" ? [aws_secretsmanager_secret.openai_api_key[0].arn] : []
        )
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
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda-secrets-read"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_region" "current" {}
