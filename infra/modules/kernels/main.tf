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

# Lambda Layer for dependencies (shared across all kernels)
resource "null_resource" "kernels_layer" {
  triggers = {
    package_json = filemd5("${path.root}/../src/kernels/package.json")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.root}/../src/kernels
      npm install --production --omit=dev
      mkdir -p ${path.root}/.terraform/kernels-layer/nodejs
      cp -r node_modules ${path.root}/.terraform/kernels-layer/nodejs/
    EOT
  }
}

data "archive_file" "kernels_layer" {
  depends_on = [null_resource.kernels_layer]
  
  type        = "zip"
  source_dir  = "${path.root}/.terraform/kernels-layer"
  output_path = "${path.root}/.terraform/kernels-layer.zip"
}

resource "aws_lambda_layer_version" "kernels_deps" {
  filename            = data.archive_file.kernels_layer.output_path
  layer_name          = "${var.project_name}-${var.environment}-kernels-deps"
  compatible_runtimes = ["nodejs20.x"]
  source_code_hash    = data.archive_file.kernels_layer.output_base64sha256
  
  description = "Kernels dependencies: pg, @noble/hashes, @noble/ed25519"
}

# Package each kernel
data "archive_file" "kernel" {
  for_each = local.kernels
  
  type        = "zip"
  source_dir  = "${path.root}/../src/kernels/${each.key}"
  output_path = "${path.root}/.terraform/kernel-${each.key}.zip"
}

# Copy db.js to each kernel directory for packaging
resource "null_resource" "copy_db_js" {
  for_each = local.kernels
  
  triggers = {
    db_js = filemd5("${path.root}/../src/kernels/db.js")
  }

  provisioner "local-exec" {
    command = "cp ${path.root}/../src/kernels/db.js ${path.root}/../src/kernels/${each.key}/db.js"
  }
}

# IAM Role for Kernels
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
    Name = "${var.project_name}-${var.environment}-kernel-role"
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
  role       = aws_iam_role.kernel.name
  policy_arn = var.secrets_read_policy_arn
}

# Lambda Functions for each kernel
resource "aws_lambda_function" "kernel" {
  for_each = local.kernels
  
  depends_on = [null_resource.copy_db_js]
  
  filename         = data.archive_file.kernel[each.key].output_path
  function_name    = "${var.project_name}-${var.environment}-${each.key}"
  role            = aws_iam_role.kernel.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.kernel[each.key].output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 300  # 5 minutes
  memory_size     = 512

  layers = [aws_lambda_layer_version.kernels_deps.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      NODE_ENV          = var.environment == "prod" ? "production" : "development"
      DATABASE_URL      = var.database_url
      APP_USER_ID       = "kernel:${each.key}"
      APP_TENANT_ID     = var.app_tenant_id
      SIGNING_KEY_HEX   = var.signing_key_hex
      KERNEL_ID         = each.value
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-${each.key}"
    KernelID  = each.value
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "kernel" {
  for_each = local.kernels
  
  name              = "/aws/lambda/${aws_lambda_function.kernel[each.key].function_name}"
  retention_in_days = 7
  
  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}-logs"
  }
}
