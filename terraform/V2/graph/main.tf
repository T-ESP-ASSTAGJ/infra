# This module is NEVER deployed — it exists only to generate graph.png
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm    = { source = "hashicorp/azurerm", version = "~> 3.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
    local      = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

variable "cloudflare_api_token" { default = "dummy" }
variable "cloudflare_zone_id"   { default = "dummy" }
variable "custom_domain"        { default = "" }
variable "custom_domain_api"    { default = "" }
variable "ssh_public_key"       { default = "ssh-rsa AAAA dummy" }

module "persistent" {
  source               = "../persistent"
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  custom_domain        = var.custom_domain
  custom_domain_api    = var.custom_domain_api
}

module "ephemeral" {
  source                         = "../ephemeral"
  vm_subnet_id                   = module.persistent.vm_subnet_id
  persistent_resource_group_name = module.persistent.resource_group_name
  appgw_backend_pool_id          = module.persistent.appgw_backend_pool_id
  ssh_public_key                 = var.ssh_public_key
}
