resource "aws_lambda_function" "this" {
  function_name    = "${var.name}-bootstrap"
  role             = aws_iam_role.this.arn
  runtime          = "nodejs24.x"
  handler          = "index.handler"
  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path)

  memory_size = 256
  timeout     = 120

  # Prevent simultaneous bootstrap executions.
  reserved_concurrent_executions = 1

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DB_HOST          = var.db_host
      ADMIN_SECRET_ARN = var.admin_secret_arn
      APP_SECRET_ARN   = var.app_secret_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.logs,
    aws_iam_role_policy.secrets,
    aws_iam_role_policy.network
  ]
}