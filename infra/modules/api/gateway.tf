resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/aws/apigateway/${var.name}-api"
  retention_in_days = 30
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "this" {
  api_id = aws_apigatewayv2_api.this.id

  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health" {
  api_id = aws_apigatewayv2_api.this.id

  route_key          = "GET /health"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.gateway.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_lambda_permission" "gateway" {
  statement_id = "AllowGatewayHealth"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/GET/health"
}

resource "aws_apigatewayv2_route" "database_health" {
  api_id = aws_apigatewayv2_api.this.id

  route_key          = "GET /health/db"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_lambda_permission" "database_health" {
  statement_id = "AllowGatewayDatabaseHealth"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/GET/health/db"
}