variable "project_name" {
  default = "jamly"
  type    = string
}

variable "location" {
  description = "The azure location where all resources should be created"
  default     = "francecentral"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
variable "db_admin_login" {
  description = "Database username"
  type        = string
  sensitive   = false
}
variable "db_admin_password" {
  description = "Database password"
  type        = string
  sensitive   = false
}
variable "db_name" {
  description = "Database name"
  type        = string
  sensitive   = false
}
