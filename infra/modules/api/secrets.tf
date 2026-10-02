resource "aws_iam_role_policy" "secrets" {
  name = "${var.name}-application-secret"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.app_secret_arn
    }]
  })
}