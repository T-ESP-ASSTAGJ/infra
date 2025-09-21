# =============================================================================
# DIGITAL OCEAN APP PLATFORM - TWO SERVICES (API + WEB)
# =============================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.38"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# =============================================================================
# APP PLATFORM WITH TWO SEPARATE SERVICES
# =============================================================================

resource "digitalocean_database_cluster" "postgres" {
  name       = "jamly-postgres-${var.environment}"
  engine     = "pg"
  version    = "16"
  size       = "db-s-1vcpu-1gb"
  region     = "fra1"
  node_count = 1
  
  timeouts {
    create = "30m"
  }
}

resource "digitalocean_app" "jamly" {
  spec {
    name   = "jamly-${var.environment}"
    region = "fra1"

    # API Service - Symfony/FrankenPHP
    service {
      name               = "api"
      instance_count     = 1
      instance_size_slug = "basic-xxs"
      
      image {
        registry_type = "GHCR"
        registry      = "t-esp-asstagj"
        repository    = "api"
        tag           = "staging"
      }  

      http_port = 80

      # Environment variables for the API
      env {
        key   = "APP_ENV"
        value = var.environment
      }
      
      env {
        key   = "APP_SECRET"
        value = var.app_secret
      }

      env {
        key = "MERCURE_JWT_SECRET"
        value = "tespmasstagjmercure"
      }

      env {
        key = "MERCURE_PUBLISHER_JWT_KEY"
        value = "tespmasstagjmercure"
      }

      env { 
        key = "MERCURE_SUBSCRIBER_JWT_KEY"
        value = "tespmasstagjmercure"
      }

      env {
        key = "DATABASE_URL"
        value = digitalocean_database_cluster.postgres.uri
      }
    }

    ingress {
      rule {
        match {
          path {
            prefix = "/api"
          }
        }
        component {
          name = "api"
        }
      }
    }
  }
}