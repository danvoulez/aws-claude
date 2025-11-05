# API Gateway Module
# Purpose: Expose HTTP endpoints for ingest, timeline, manifests

# HTTP API Gateway
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "LogLine API Gateway"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-api"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.main.name}"
  retention_in_days = 7
  
  tags = {
    Name = "${var.project_name}-${var.environment}-api-logs"
  }
}

# Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-api-stage"
  }
}

# Integration with Stage-0 Lambda
resource "aws_apigatewayv2_integration" "stage0" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.stage0_lambda_invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Route: POST /api/spans
resource "aws_apigatewayv2_route" "post_spans" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/spans"
  target    = "integrations/${aws_apigatewayv2_integration.stage0.id}"
}

# Route: GET /api/timeline
resource "aws_apigatewayv2_route" "get_timeline" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /api/timeline"
  target    = "integrations/${aws_apigatewayv2_integration.stage0.id}"
}

# Route: GET /api/manifest/{name}
resource "aws_apigatewayv2_route" "get_manifest" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /api/manifest/{name}"
  target    = "integrations/${aws_apigatewayv2_integration.stage0.id}"
}

# Route: POST /api/execute/{function_id}
resource "aws_apigatewayv2_route" "post_execute" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/execute/{function_id}"
  target    = "integrations/${aws_apigatewayv2_integration.stage0.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.stage0_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
