# Kernels Lambda Module
# Purpose: Deploy all 5 core kernels as Lambda functions

locals {
  kernels = {
    run_code        = "00000000-0000-4000-8000-000000000001"
    observer_bot    = "00000000-0000-4000-8000-000000000002"
    request_worker  = "00000000-0000-4000-8000-000000000003"
    policy_agent    = "00000000-0000-4000-8000-000000000004"
    provider_exec   = "00000000-0000-4000-8000-000000000005"
  }
}

# Shared Lambda execution role for all kernels
resource "aws_iam_role" "kernel" {
  name = "${var.project_name}-${var.environment}-kernel-role"
  
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
    Name        = "${var.project_name}-${var.environment}-kernel-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "kernel_basic" {
  role       = aws_iam_role.kernel.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy
resource "aws_iam_role_policy_attachment" "kernel_vpc" {
  role       = aws_iam_role.kernel.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach secrets read policy
resource "aws_iam_role_policy_attachment" "kernel_secrets" {
  count      = var.secrets_read_policy_arn != "" ? 1 : 0
  role       = aws_iam_role.kernel.name
  policy_arn = var.secrets_read_policy_arn
}

# Lambda Layer for dependencies
resource "null_resource" "kernel_layer" {
  triggers = {
    package_json = filemd5("${path.module}/../../../src/kernels/package.json")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/../../../.build/nodejs
      cd ${path.module}/../../../src/kernels
      npm install --production --prefix ${path.module}/../../../.build/nodejs
      cd ${path.module}/../../../.build
      zip -r kernel_layer.zip nodejs
      rm -rf nodejs
    EOT
  }
}

resource "aws_lambda_layer_version" "kernel_deps" {
  filename            = "${path.module}/../../../.build/kernel_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-kernel-deps"
  compatible_runtimes = ["nodejs20.x"]
  
  depends_on = [null_resource.kernel_layer]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Package each kernel
data "archive_file" "kernel" {
  for_each = local.kernels
  
  type        = "zip"
  source_dir  = "${path.module}/../../../src/kernels/${each.key}"
  output_path = "${path.module}/../../../.build/kernel_${each.key}.zip"
}

# Create Lambda function for each kernel
resource "aws_lambda_function" "kernel" {
  for_each = local.kernels
  
  filename         = data.archive_file.kernel[each.key].output_path
  function_name    = "${var.project_name}-${var.environment}-${each.key}"
  role            = aws_iam_role.kernel.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.kernel[each.key].output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 60
  memory_size     = 512
  
  layers = [aws_lambda_layer_version.kernel_deps.arn]
  
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }
  
  environment {
    variables = {
      NODE_ENV        = var.environment == "prod" ? "production" : "development"
      DATABASE_URL    = var.database_url
      APP_USER_ID     = "kernel:${each.key}"
      APP_TENANT_ID   = var.tenant_id
      SIGNING_KEY_HEX = var.signing_key_hex
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.kernel_basic,
    aws_iam_role_policy_attachment.kernel_vpc
  ]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}"
    Environment = var.environment
    ManagedBy   = "terraform"
    KernelType  = each.key
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "kernel" {
  for_each = local.kernels
  
  name              = "/aws/lambda/${aws_lambda_function.kernel[each.key].function_name}"
  retention_in_days = 7
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
