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