# Azure PaaS Deployment - V1

This Terraform configuration deploys a multi-service application to Azure App Services using Docker containers from GitHub Container Registry (GHCR).

## Architecture

- **API Service**: Symfony/FrankenPHP application
- **Web Service**: Next.js application
- **Database**: Azure PostgreSQL Flexible Server
- **Platform**: Azure App Services (PaaS)

## Prerequisites

1. **Azure CLI** installed and authenticated (`az login`)
2. **Terraform** >= 1.0
3. **Docker images** published to GHCR:
   - `ghcr.io/t-esp-asstagj/api`
   - `ghcr.io/t-esp-asstagj/web`

> **Note**: This configuration uses Azure CLI for authentication. Make sure you're logged in with `az login` before running Terraform commands. No need to specify `subscription_id` manually!

## Workspace Management

This configuration uses Terraform workspaces to manage different environments. **The workspace name automatically becomes the environment name** (dev, staging, production), so you don't need to pass the environment variable separately.

### Initial Setup

```bash
# Navigate to the V1 directory
cd terraform/V1

# Initialize Terraform
terraform init
```

### Working with Workspaces

#### List available workspaces
```bash
terraform workspace list
```

#### Create and switch to a workspace
```bash
# For staging
terraform workspace new staging
# or switch to existing
terraform workspace select staging

# For production
terraform workspace new production
# or switch to existing
terraform workspace select production

### Deploy to an Environment

#### Staging Environment
```bash
# Switch to staging workspace (environment is automatically set to "staging")
terraform workspace select staging

# Plan with staging variables
terraform plan -var-file="staging.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"

# Apply
terraform apply -var-file="staging.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"
```

#### Production Environment
```bash
# Switch to production workspace (environment is automatically set to "production")
terraform workspace select production

# Plan with production variables
terraform plan -var-file="production.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"

# Apply
terraform apply -var-file="production.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"
```

#### Development Environment
```bash
# Switch to dev workspace (environment is automatically set to "dev")
terraform workspace select dev

# Plan with dev variables
terraform plan -var-file="dev.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"

# Apply
terraform apply -var-file="dev.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"
```

### Using Auto-loaded Variables (Recommended)

Instead of passing sensitive variables via command line, create a `.tfvars` file for secrets:

```bash
# Create terraform.auto.tfvars (automatically loaded, add to .gitignore!)
cat > terraform.auto.tfvars <<EOF
db_admin_password  = "your-strong-db-password"
app_secret         = "your-symfony-app-secret"
mercure_jwt_secret = "your-mercure-jwt-secret"
EOF
```

Then deploy with simplified commands:
```bash
# Make sure you're logged in with Azure CLI
az login

# Select workspace and deploy
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

> **Note**: The `terraform.auto.tfvars` file is automatically loaded, so you don't need to specify it in the command!

## Environment-Specific Configurations

### Development (dev.tfvars)
- **App Service SKU**: F1 (Free tier)
- **Database SKU**: B_Standard_B1ms (Burstable)
- **Docker Tag**: dev

### Staging (staging.tfvars)
- **App Service SKU**: B1 (Basic tier)
- **Database SKU**: B_Standard_B1ms (Burstable)
- **Docker Tag**: staging

### Production (production.tfvars)
- **App Service SKU**: P1v2 (Premium tier)
- **Database SKU**: GP_Standard_D2s_v3 (General Purpose)
- **Docker Tag**: latest

## Outputs

After deployment, you can view the outputs:

```bash
terraform output
```

Available outputs:
- `api_url`: HTTPS URL of the API service
- `web_url`: HTTPS URL of the Web service
- `postgresql_server_fqdn`: Database server FQDN
- `app_service_plan_name`: Name of the App Service Plan
- And more...

## Destroy Resources

```bash
# Make sure you're in the correct workspace
terraform workspace select staging

# Destroy with the corresponding tfvars file
terraform destroy -var-file="staging.tfvars" \
  -var="db_admin_password=YOUR_DB_PASSWORD" \
  -var="app_secret=YOUR_APP_SECRET"

# Or if using terraform.auto.tfvars
terraform destroy -var-file="staging.tfvars"
```

## State Management

Each workspace maintains its own state file, allowing you to manage multiple environments independently while using the same Terraform configuration.

State files are stored in:
- `terraform.tfstate.d/staging/`
- `terraform.tfstate.d/production/`
- `terraform.tfstate.d/dev/`

## Security Notes

1. **Never commit sensitive values** to version control
2. Add `terraform.auto.tfvars` and `*.auto.tfvars` to `.gitignore`
3. Use Azure Key Vault or environment variables for production secrets
4. Rotate database passwords regularly
5. Use strong, unique values for `app_secret` and JWT secrets

## Docker Image Authentication

If your GHCR images are private, you'll need to configure authentication:

```bash
# Set App Service container registry credentials
az webapp config container set \
  --name <app-name> \
  --resource-group <resource-group> \
  --docker-registry-server-url https://ghcr.io \
  --docker-registry-server-user <github-username> \
  --docker-registry-server-password <github-pat>
```

Or add to the Terraform configuration using `docker_registry_username` and `docker_registry_password` in the `site_config` block.
