module "network" {
  source = "../../modules/network"

  name   = "solirius-dev"
  region = "eu-west-2"
}

module "database" {
  source = "../../modules/database"

  name              = "solirius-dev"
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.db_security_group_id

  engine_version   = var.db_engine_version
  instance_class   = "db.t3.medium"
  parameter_family = "sqlserver-web-15.0"
}

module "api" {
  source = "../../modules/api"

  name              = "solirius-dev"
  zip_path          = abspath("${path.root}/../../../dist/api.zip")
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.lambda_security_group_id

  db_host        = module.database.host
  app_secret_arn = module.database.app_secret_arn
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  name     = "solirius-dev"
  zip_path = abspath("${path.root}/../../../dist/bootstrap.zip")

  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.lambda_security_group_id

  db_host          = module.database.host
  admin_secret_arn = module.database.admin_secret_arn
  app_secret_arn   = module.database.app_secret_arn
}

module "delivery" {
  source = "../../modules/delivery"

  name               = "solirius-dev"
  github_repository  = "rsharma08/aws-node-sql"
  github_environment = "dev"

  function_arn = module.api.function_arn
}