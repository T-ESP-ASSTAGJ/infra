variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment (staging/production)"
  type        = string
  default     = "staging"
}

variable "app_secret" {
  description = "Symfony APP_SECRET"
  type        = string
}

variable "api_image_tag" {
  description = "Docker image tag for the API service"
  type        = string
  default     = "latest"
}

variable "web_image_tag" {
  description = "Docker image tag for the Web service"
  type        = string
  default     = "latest"
}