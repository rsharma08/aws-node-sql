resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}-api"
  retention_in_days = 30
}

resource "aws_iam_role" "this" {
  name = "${var.name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "logs" {
  name = "${var.name}-logs"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.this.arn}:*"
    }]
  })
}

resource "aws_iam_role_policy" "network" {
  name = "${var.name}-vpc-access"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "this" {
  function_name = "${var.name}-api"
  role          = aws_iam_role.this.arn

  runtime = "nodejs24.x"
  handler = "app/index.handler"

  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path)

  memory_size = 256
  timeout     = 10

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }

  environment {
    variables = {
      NODE_ENV      = "production"
      DB_HOST       = var.db_host
      DB_PORT       = "1433"
      DB_SECRET_ARN = var.app_secret_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.logs,
    aws_iam_role_policy.network,
    aws_iam_role_policy.secrets
  ]
}