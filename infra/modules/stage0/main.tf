# Stage-0 Lambda Module
# Purpose: Deploy the bootstrap loader that can execute kernels

# Package Stage-0 Lambda code
data "archive_file" "stage0_package" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/stage0"
  output_path = "${path.module}/../../../.build/stage0.zip"
  excludes    = ["node_modules"]
}

# Lambda execution role
resource "aws_iam_role" "stage0" {
  name = "${var.project_name}-${var.environment}-stage0-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-stage0-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "stage0_basic" {
  role       = aws_iam_role.stage0.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy
resource "aws_iam_role_policy_attachment" "stage0_vpc" {
  role       = aws_iam_role.stage0.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach secrets read policy (passed from secrets module)
resource "aws_iam_role_policy_attachment" "stage0_secrets" {
  count      = var.secrets_read_policy_arn != "" ? 1 : 0
  role       = aws_iam_role.stage0.name
  policy_arn = var.secrets_read_policy_arn
}

# Lambda Layer for dependencies (pg, @noble/hashes, @noble/ed25519)
resource "aws_lambda_layer_version" "stage0_deps" {
  filename            = "${path.module}/../../../.build/stage0_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-stage0-deps"
  compatible_runtimes = ["nodejs20.x"]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create layer package
resource "null_resource" "stage0_layer" {
  triggers = {
    package_json = filemd5("${path.module}/../../../src/stage0/package.json")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/../../../.build/nodejs
      cd ${path.module}/../../../src/stage0
      npm install --production --prefix ${path.module}/../../../.build/nodejs
      cd ${path.module}/../../../.build
      zip -r stage0_layer.zip nodejs
      rm -rf nodejs
    EOT
  }
}

# Stage-0 Lambda function
resource "aws_lambda_function" "stage0" {
  filename         = data.archive_file.stage0_package.output_path
  function_name    = "${var.project_name}-${var.environment}-stage0"
  role            = aws_iam_role.stage0.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.stage0_package.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 512
  
  layers = [aws_lambda_layer_version.stage0_deps.arn]
  
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }
  
  environment {
    variables = {
      NODE_ENV          = var.environment == "prod" ? "production" : "development"
      DATABASE_URL      = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}/${var.db_name}?sslmode=require"
      APP_USER_ID       = "edge:stage0"
      APP_TENANT_ID     = var.tenant_id
      SIGNING_KEY_HEX   = var.signing_key_hex
      BOOT_FUNCTION_ID  = var.boot_function_id
    }
  }
  
  depends_on = [
    null_resource.stage0_layer,
    aws_iam_role_policy_attachment.stage0_basic,
    aws_iam_role_policy_attachment.stage0_vpc
  ]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-stage0"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "stage0" {
  name              = "/aws/lambda/${aws_lambda_function.stage0.function_name}"
  retention_in_days = 7
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-stage0-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
