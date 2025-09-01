# =============================================================================
# STAGING BACKEND CONFIGURATION - DIGITALOCEAN SPACES
# =============================================================================

terraform {
  backend "s3" {
    # DigitalOcean Spaces configuration
    endpoint                    = "https://fra1.digitaloceanspaces.com"
    region                     = "fra1"
    bucket                     = "jamly-terraform-state"
    key                        = "staging/terraform.tfstate"

    # Force path-style access (required for DigitalOcean Spaces)
    use_path_style             = true

    # Disable AWS-specific features
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    # Disable workspaces (DigitalOcean Spaces doesn't support them well)
    workspace_key_prefix       = ""
  }
}