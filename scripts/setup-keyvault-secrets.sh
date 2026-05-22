#!/usr/bin/env bash
set -euo pipefail

# Populate the four secrets that ESO's ExternalSecret needs.
# Run this once after `terraform apply` on the persistent layer.
#
# Requirements: az CLI logged in
#
# Usage:
#   ./scripts/setup-keyvault-secrets.sh

KEYVAULT_NAME="jamly-persistent-kvaalt"

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

set_secret_from_file() {
  local secret_name="$1"
  local prompt_label="$2"
  local file_path

  printf "Enter path to %s file (Enter to skip): " "${prompt_label}"
  read -r file_path

  if [[ -z "${file_path}" ]]; then
    echo "  SKIPPED (empty value)"
    return
  fi
  if [[ ! -f "${file_path}" ]]; then
    echo "  SKIPPED (file not found: ${file_path})"
    return
  fi

  az keyvault secret set \
    --vault-name "${KEYVAULT_NAME}" \
    --name "${secret_name}" \
    --file "${file_path}" \
    --output none

  echo "  OK: ${secret_name}"
}

# ── Set secrets ───────────────────────────────────────────────────────────────

set_secret "app-secret"                      "Symfony APP_SECRET"
set_secret "mercure-jwt-secret"              "Mercure JWT secret"
set_secret "database-url"                    "Database URL (e.g. postgresql://user:pass@host:5432/db)"
set_secret "github-token"                    "GitHub Personal Access Token (read:repo)"
set_secret "mailer-dsn"                      "Mailer DSN (e.g. gmail+smtp://user:app-password@default)"
set_secret "jwt-passphrase"                  "JWT passphrase"
set_secret "azure-storage-account-key"       "Azure Storage account key"
set_secret "azure-storage-connection-string" "Azure Storage connection string"
set_secret_from_file "jwt-private-key"       "JWT private key (config/jwt/private.pem)"
set_secret_from_file "jwt-public-key"        "JWT public key  (config/jwt/public.pem)"
set_secret_from_file "firebase-credentials"  "Firebase service account JSON (jamly-6048b-firebase.json)"

echo ""
echo "Done. Verify with:"
echo "  az keyvault secret list --vault-name ${KEYVAULT_NAME} --query \"[].name\" -o tsv"
