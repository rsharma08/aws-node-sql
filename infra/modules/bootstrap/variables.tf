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
  type = string
}

variable "admin_secret_arn" {
  type = string
}

variable "app_secret_arn" {
  type = string
}