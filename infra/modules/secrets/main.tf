# Secrets Manager Module
# Purpose: Store and manage sensitive credentials

# Database password secret
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}/${var.environment}/db-password"
  description = "PostgreSQL database password"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# Ed25519 signing key secret
resource "aws_secretsmanager_secret" "signing_key" {
  name        = "${var.project_name}/${var.environment}/signing-key"
  description = "Ed25519 signing key for span signatures"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-signing-key"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "signing_key" {
  secret_id = aws_secretsmanager_secret.signing_key.id
  secret_string = jsonencode({
    private_key = var.signing_key_hex
    public_key  = var.public_key_hex
  })
}

# Optional: OpenAI API key
resource "aws_secretsmanager_secret" "openai_key" {
  count       = var.openai_api_key != "" ? 1 : 0
  name        = "${var.project_name}/${var.environment}/openai-key"
  description = "OpenAI API key for AI features"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-openai-key"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "openai_key" {
  count         = var.openai_api_key != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.openai_key[0].id
  secret_string = var.openai_api_key
}
