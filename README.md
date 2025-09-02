# Infrastructure Management

![Staging Infrastructure](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/jamlypr/0d7fa0445df4861e8c8fcf9c82ae5b64/raw/infra-staging.json&logo=digitalocean)
![Production Infrastructure](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/jamlypr/0d7fa0445df4861e8c8fcf9c82ae5b64/raw/infra-production.json&logo=digitalocean)

This repository manages DigitalOcean infrastructure using OpenTofu (Terraform) and GitHub Actions.

## 🚀 Quick Start

### Prerequisites
Your repository secrets are already configured:
- ✅ `DO_TOKEN` - DigitalOcean API token
- ✅ `SPACES_ACCESS_ID` - Spaces access key
- ✅ `SPACES_SECRET_KEY` - Spaces secret key
- ✅ `INFRASTRUCTURE_PROJECT_ID` - Project ID

### How to Deploy Infrastructure

1. **Go to Actions tab**
2. **Click "🏗️ Infrastructure"**
3. **Click "Run workflow"**
4. **Select your options**:
    - Environment: `staging` or `production`
    - Action: `plan`, `apply`, `destroy`, or `status`
    - Auto-approve: ✅ for immediate execution

## 📋 Available Actions

| Action | Description | Safe? |
|--------|-------------|-------|
| `status` | Check current infrastructure | ✅ Read-only |
| `plan` | Preview what will change | ✅ Read-only |
| `apply` | Deploy/update infrastructure | ⚠️ Makes changes |
| `destroy` | Remove all infrastructure | ❌ Destructive |

## 🌟 Common Workflows

### Deploy Staging
1. Actions → Infrastructure → Run workflow
2. Environment: `staging`, Action: `apply`, Auto-approve: ✅

### Check What's Running
1. Actions → Infrastructure → Run workflow
2. Environment: `staging`, Action: `status`

### Preview Production Changes
1. Actions → Infrastructure → Run workflow
2. Environment: `production`, Action: `plan`

### Clean Up Environment
1. Actions → Infrastructure → Run workflow
2. Environment: `staging`, Action: `destroy`, Auto-approve: ✅

## 📊 Automatic Monitoring

The `📊 Infrastructure Status` workflow runs every 4 hours to check if your infrastructure is online and updates the status badges above.

### Setting Up Status Badges (Optional)
To enable the status badges:
1. Create a [GitHub Gist](https://gist.github.com/) (can be private)
2. Add the Gist ID to your repository variables as `BADGE_GIST_ID`
3. Replace `[gist-id]` in the badges above with your actual Gist ID

## 🏗️ Infrastructure Details

### Staging Environment
- **Location**: `terraform/environments/staging/`
- **Default**: 2 VMs, small sizes for testing
- **Network**: Private VPC

### Production Environment
- **Location**: `terraform/environments/production/`
- **Default**: 3 VMs, larger sizes for production load
- **Network**: Private VPC
- **Protection**: Requires manual approval for changes

## 🔒 Safety Features

- **Manual Approval**: Required for `apply`/`destroy` unless auto-approve is checked
- **Production Protection**: GitHub environment protection for production
- **Plan First**: Always run `plan` to preview changes before `apply`
- **State Management**: Remote state stored securely in DigitalOcean Spaces

## 🆘 Need Help?

- **Check Action Logs**: Detailed output in GitHub Actions
- **Start Small**: Use staging environment first
- **Plan Before Apply**: Always preview changes
- **Ask Questions**: Create an issue if you need help

---

**Quick Links**: [Actions](../../actions) • [DigitalOcean Console](https://cloud.digitalocean.com/projects)