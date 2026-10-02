variable "name" {
  type = string
}

variable "zip_path" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "db_host" {
  description = "Private RDS hostname."
  type        = string
}

variable "app_secret_arn" {
  description = "Secret containing the restricted SQL application credentials."
  type        = string
}