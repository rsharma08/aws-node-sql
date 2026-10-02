output "host" { value = aws_db_instance.this.address }
output "admin_secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
output "app_secret_arn" { value = aws_secretsmanager_secret.app.arn }
