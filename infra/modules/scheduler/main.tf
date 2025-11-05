# EventBridge Scheduler Module
# Purpose: Cron jobs for kernels (observer, worker, policy, midnight)

# Observer Bot - Every 10 seconds (rate-based)
resource "aws_cloudwatch_event_rule" "observer" {
  name                = "${var.project_name}-${var.environment}-observer"
  description         = "Trigger observer_bot every 10 seconds"
  schedule_expression = "rate(10 seconds)"
  
  tags = { 
    Name        = "${var.project_name}-${var.environment}-observer" 
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "observer" {
  rule      = aws_cloudwatch_event_rule.observer.name
  target_id = "observer-lambda"
  arn       = var.observer_lambda_arn
}

resource "aws_lambda_permission" "observer" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.observer_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.observer.arn
}

# Request Worker - Every 10 seconds
resource "aws_cloudwatch_event_rule" "worker" {
  name                = "${var.project_name}-${var.environment}-worker"
  description         = "Trigger request_worker every 10 seconds"
  schedule_expression = "rate(10 seconds)"
  
  tags = { 
    Name        = "${var.project_name}-${var.environment}-worker" 
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "worker" {
  rule      = aws_cloudwatch_event_rule.worker.name
  target_id = "worker-lambda"
  arn       = var.worker_lambda_arn
}

resource "aws_lambda_permission" "worker" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.worker_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.worker.arn
}

# Policy Agent - Every 30 seconds
resource "aws_cloudwatch_event_rule" "policy" {
  name                = "${var.project_name}-${var.environment}-policy"
  description         = "Trigger policy_agent every 30 seconds"
  schedule_expression = "rate(30 seconds)"
  
  tags = { 
    Name        = "${var.project_name}-${var.environment}-policy" 
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "policy" {
  rule      = aws_cloudwatch_event_rule.policy.name
  target_id = "policy-lambda"
  arn       = var.policy_lambda_arn
}

resource "aws_lambda_permission" "policy" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.policy_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.policy.arn
}

# Midnight Ruler - 00:00 Europe/Paris
# Using EventBridge Scheduler (supports timezones)
resource "aws_scheduler_schedule" "midnight" {
  name       = "${var.project_name}-${var.environment}-midnight"
  group_name = "default"
  
  flexible_time_window {
    mode = "OFF"
  }
  
  schedule_expression          = "cron(0 0 * * ? *)"
  schedule_expression_timezone = "Europe/Paris"
  
  target {
    arn      = var.run_code_lambda_arn
    role_arn = aws_iam_role.scheduler.arn
    
    input = jsonencode({
      trigger          = "midnight_ruler"
      boot_function_id = "00000000-0000-4000-8000-000000000001"
      timezone         = "Europe/Paris"
    })
  }
}

# IAM role for EventBridge Scheduler
resource "aws_iam_role" "scheduler" {
  name = "${var.project_name}-${var.environment}-scheduler-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
    }]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-scheduler-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  role = aws_iam_role.scheduler.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.run_code_lambda_arn
    }]
  })
}
