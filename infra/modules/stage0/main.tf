# Stage-0 Lambda Module
# Purpose: Deploy the bootstrap loader that can execute kernels

# Data source for packaging Lambda code
data "archive_file" "stage0" {
  type        = "zip"
  source_dir  = "${path.root}/../src/stage0"
  output_path = "${path.root}/.terraform/stage0.zip"
  excludes    = ["node_modules", "package-lock.json"]
}

# Lambda Layer for dependencies
resource "null_resource" "stage0_layer" {
  triggers = {
    package_json = filemd5("${path.root}/../src/stage0/package.json")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.root}/../src/stage0
      npm install --production --omit=dev
      mkdir -p ${path.root}/.terraform/layer/nodejs
      cp -r node_modules ${path.root}/.terraform/layer/nodejs/
    EOT
  }
}

data "archive_file" "stage0_layer" {
  depends_on = [null_resource.stage0_layer]
  
  type        = "zip"
  source_dir  = "${path.root}/.terraform/layer"
  output_path = "${path.root}/.terraform/stage0-layer.zip"
}

resource "aws_lambda_layer_version" "stage0_deps" {
  filename            = data.archive_file.stage0_layer.output_path
  layer_name          = "${var.project_name}-${var.environment}-stage0-deps"
  compatible_runtimes = ["nodejs20.x"]
  source_code_hash    = data.archive_file.stage0_layer.output_base64sha256
  
  description = "Stage-0 dependencies: pg, @noble/hashes, @noble/ed25519"
}

# IAM Role for Stage-0 Lambda
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
    Name = "${var.project_name}-${var.environment}-stage0-role"
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

# Attach secrets read policy
resource "aws_iam_role_policy_attachment" "stage0_secrets" {
  role       = aws_iam_role.stage0.name
  policy_arn = var.secrets_read_policy_arn
}

# Stage-0 Lambda Function
resource "aws_lambda_function" "stage0" {
  filename         = data.archive_file.stage0.output_path
  function_name    = "${var.project_name}-${var.environment}-stage0"
  role            = aws_iam_role.stage0.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.stage0.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 300  # 5 minutes
  memory_size     = 512

  layers = [aws_lambda_layer_version.stage0_deps.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      NODE_ENV          = var.environment == "prod" ? "production" : "development"
      DATABASE_URL      = var.database_url
      APP_USER_ID       = var.app_user_id
      APP_TENANT_ID     = var.app_tenant_id
      SIGNING_KEY_HEX   = var.signing_key_hex
      BOOT_FUNCTION_ID  = var.boot_function_id
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-stage0"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "stage0" {
  name              = "/aws/lambda/${aws_lambda_function.stage0.function_name}"
  retention_in_days = 7
  
  tags = {
    Name = "${var.project_name}-${var.environment}-stage0-logs"
  }
}
