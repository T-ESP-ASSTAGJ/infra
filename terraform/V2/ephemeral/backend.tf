terraform {
  backend "s3" {
    bucket = "terraformbackend"
    key    = "ephemeral/terraform.tfstate"

    endpoints = {
      s3 = "https://ab07070719a0cdf156dcde612f7eb9de.r2.cloudflarestorage.com"
    }

    region                      = "auto"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
