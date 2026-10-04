variable "aws_region" {
  type    = string
  default = "eu-west-2"
}
variable "project" {
  type    = string
  default = "solirius"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project))
    error_message = "Use 3-20 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Use dev, staging or production."
  }
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.medium"
}
variable "db_engine_version" {
  type        = string
  default     = "15.00.4480.2.v1"
  description = "Required exact currently orderable SQL Server 2019 Web engine version."
}
variable "db_parameter_family" {
  type        = string
  default     = "sqlserver-web-15.0"
  description = "Must match the selected engine major version."
}
variable "github_repository" {
  type        = string
  default     = "rsharma08/aws-node-sql"
  description = "GitHub owner/repository used for API deployments."
}

variable "github_environment" {
  type        = string
  default     = "dev"
  description = "GitHub environment used by the deployment workflow."
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = "Existing GitHub OIDC provider ARN; null creates one."
}
variable "github_oidc_subject" {
  description = "Exact GitHub OIDC subject allowed to deploy"
  type        = string
}