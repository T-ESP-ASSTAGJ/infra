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