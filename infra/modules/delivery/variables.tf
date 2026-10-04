variable "name" {
  type = string
}

variable "github_repository" {
  type        = string
  description = "GitHub owner/repository"
}

variable "github_environment" {
  type    = string
  default = "dev"
}

variable "function_arn" {
  type = string
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