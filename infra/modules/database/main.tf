resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-database"
  subnet_ids = var.subnet_ids
}
resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-"
  family      = var.parameter_family
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
  lifecycle { create_before_destroy = true }
}
resource "aws_db_instance" "this" {
  identifier                      = "${var.name}-sqlserver"
  engine                          = "sqlserver-web"
  engine_version                  = var.engine_version
  instance_class                  = var.instance_class
  license_model                   = "license-included"
  username                        = "db_admin"
  manage_master_user_password     = true
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_type                    = "gp3"
  storage_encrypted               = true
  publicly_accessible             = false
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [var.security_group_id]
  parameter_group_name            = aws_db_parameter_group.this.name
  backup_retention_period         = 7
  backup_window                   = "01:00-02:00"
  maintenance_window              = "sun:03:00-sun:04:00"
  auto_minor_version_upgrade      = true
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["error"]
  deletion_protection             = true
  skip_final_snapshot             = true
  final_snapshot_identifier       = "${var.name}-final-snapshot"
  multi_az                        = false
  apply_immediately               = false
  # Web supports the requested small class, but not native Multi-AZ.
  # Never set db_name for RDS SQL Server; create the application database via SQL.
}
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name}/database/application"
  description             = "Restricted SQL application login. Provision value outside Terraform."
  recovery_window_in_days = 30
  # Default aws/secretsmanager KMS encryption. No secret value in Terraform state.
}
