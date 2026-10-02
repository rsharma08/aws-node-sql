data "aws_availability_zones" "available" { state = "available" }
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-private-${count.index}" }
}
resource "aws_route_table" "private" { vpc_id = aws_vpc.this.id }
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "lambda" {
  name        = "${var.name}-lambda"
  description = "API: SQL and Secrets Manager egress only"
  vpc_id      = aws_vpc.this.id
}
resource "aws_security_group" "db" {
  name        = "${var.name}-database"
  description = "SQL from API security group only"
  vpc_id      = aws_vpc.this.id
}
resource "aws_security_group" "endpoint" {
  name        = "${var.name}-secrets-endpoint"
  description = "HTTPS from API security group only"
  vpc_id      = aws_vpc.this.id
}
resource "aws_vpc_security_group_egress_rule" "sql" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}
resource "aws_vpc_security_group_ingress_rule" "sql" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}
resource "aws_vpc_security_group_egress_rule" "secrets" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_ingress_rule" "secrets" {
  security_group_id            = aws_security_group.endpoint.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_endpoint" "secrets" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoint.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue"
      ]
      Resource = "*"
    }]
  })
  # Endpoint policy is an additional boundary; Lambda IAM scopes the exact secret.
}
