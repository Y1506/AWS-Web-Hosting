# terraform/modules/api_gateway/main.tf

# ── VPC LINK (HTTP API — connects API Gateway to ALB in VPC) ─────
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-vpc-link"
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [var.alb_sg_id]
}

# ── HTTP API GATEWAY (lower latency, lower cost than REST API) ───
# FREE TIER: 1M HTTP API calls/month for 12 months
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.project_name}"

  # CORS configuration
  cors_configuration {
    allow_headers = ["Content-Type", "Authorization", "X-Request-ID"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["https://www.${var.domain_name}"]
    max_age       = 3600
  }
}

# ── INTEGRATION (API GW → ALB via VPC Link) ──────────────────────
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.alb_listener_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id

  request_parameters = {
    "overwrite:header.X-Request-ID" = "$context.requestId"
  }
}

# ── ROUTES ───────────────────────────────────────────────────────
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# ── STAGE (deployment environment) ───────────────────────────────
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  depends_on = [aws_apigatewayv2_route.default]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId    = "$context.requestId"
      ip           = "$context.identity.sourceIp"
      requestTime  = "$context.requestTime"
      httpMethod   = "$context.httpMethod"
      routeKey     = "$context.routeKey"
      status       = "$context.status"
      protocol     = "$context.protocol"
      responseTime = "$context.integrationLatency"
    })
  }

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 2000
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api-gateway/${var.project_name}"
  retention_in_days = 30
}