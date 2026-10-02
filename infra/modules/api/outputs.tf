output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "health_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/health"
}

output "health_invoke_arn" {
  value = "${aws_apigatewayv2_api.this.execution_arn}/$default/GET/health"
}

output "database_health_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/health/db"
}

output "database_health_invoke_arn" {
  value = "${aws_apigatewayv2_api.this.execution_arn}/$default/GET/health/db"
}