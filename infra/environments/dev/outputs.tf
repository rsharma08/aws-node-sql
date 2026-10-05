# output "api_url" { value = module.api.url }
# output "lambda_function_name" { value = module.api.function_name }
# output "github_deployment_role_arn" { value = module.delivery.role_arn }
# output "database_host" { value = module.database.host }
# output "admin_secret_arn" { value = module.database.admin_secret_arn }
# output "app_secret_arn" { value = module.database.app_secret_arn }

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.subnet_ids
}

output "health_url" {
  value = module.api.health_url
}

output "health_invoke_arn" {
  value = module.api.health_invoke_arn
}

output "database_health_url" {
  value = module.api.database_health_url
}

output "database_health_invoke_arn" {
  value = module.api.database_health_invoke_arn
}

output "bootstrap_function_name" {
  value = module.bootstrap.function_name
}

output "github_deploy_role_arn" {
  value = module.delivery.deploy_role_arn
}

output "api_function_name" {
  value = module.api.function_name
}
output "aws_region" {
  value = var.aws_region
}
