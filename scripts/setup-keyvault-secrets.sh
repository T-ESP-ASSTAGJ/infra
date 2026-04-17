#!/usr/bin/env bash
set -euo pipefail

# Populate the four secrets that ESO's ExternalSecret needs.
# Run this once after `terraform apply` on the persistent layer.
#
# Requirements: az CLI logged in
#
# Usage:
#   ./scripts/setup-keyvault-secrets.sh

KEYVAULT_NAME="jamly-persistent-keyvl"

echo "Target Key Vault: ${KEYVAULT_NAME}"
echo ""

# ── Prompt helper ─────────────────────────────────────────────────────────────

set_secret() {
  local secret_name="$1"
  local prompt_label="$2"
  local secret_value

  printf "Enter %s: " "${prompt_label}"
  read -rs secret_value
  echo ""

  if [[ -z "${secret_value}" ]]; then
    echo "  SKIPPED (empty value)"
    return
  fi

  az keyvault secret set \
    --vault-name "${KEYVAULT_NAME}" \
    --name "${secret_name}" \
    --value "${secret_value}" \
    --output none

  echo "  OK: ${secret_name}"
}

# ── Set secrets ───────────────────────────────────────────────────────────────

set_secret "app-secret"          "Symfony APP_SECRET"
set_secret "mercure-jwt-secret"  "Mercure JWT secret"
set_secret "database-url"        "Database URL (e.g. postgresql://user:pass@host:5432/db)"
set_secret "mercure-public-url"  "Mercure public URL (e.g. https://example.com/.well-known/mercure)"
set_secret "github-token"         "GitHub Personal Access Token (read:repo)"

echo ""
echo "Done. Verify with:"
echo "  az keyvault secret list --vault-name ${KEYVAULT_NAME} --query \"[].name\" -o tsv"
