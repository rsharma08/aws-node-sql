module "network" {
  source = "../../modules/network"

  name   = local.name
  region = var.aws_region
}

module "database" {
  source = "../../modules/database"

  name              = local.name
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.db_security_group_id

  engine_version   = var.db_engine_version
  instance_class   = var.db_instance_class
  parameter_family = var.db_parameter_family
}

module "api" {
  source = "../../modules/api"

  name              = local.name
  zip_path          = abspath("${path.root}/../../../dist/api.zip")
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.lambda_security_group_id

  db_host        = module.database.host
  app_secret_arn = module.database.app_secret_arn
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  name     = local.name
  zip_path = abspath("${path.root}/../../../dist/bootstrap.zip")

  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.lambda_security_group_id

  db_host          = module.database.host
  admin_secret_arn = module.database.admin_secret_arn
  app_secret_arn   = module.database.app_secret_arn
}

module "delivery" {
  source = "../../modules/delivery"

  name                = local.name
  github_repository   = var.github_repository
  github_environment  = var.github_environment
  oidc_provider_arn   = var.oidc_provider_arn
  github_oidc_subject = var.github_oidc_subject

  function_arn = module.api.function_arn
}

locals {
  name = "${var.project}-${var.environment}"
}