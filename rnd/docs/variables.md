# Variable Reference

This document describes the main variable sources used by the `rnd/ansible` lab.

## Variable Files

### `ansible/network_vars.yml`

Used by:

- `playbooks/gateway_server_setup.yml`

Purpose:

- generated host and network values used by the OpenBSD gateway configuration

Variables:

- `host_ip`: IP assigned to the host-side network
- `host_network`: network base
- `host_netmask`: subnet mask
- `host_cidr`: CIDR prefix length
- `default_gateway`: upstream gateway used by the host
- `target_ip`: target IP used by generated host mapping
- `target_interface`: interface used for the target-side network path
- `host_interface`: host bridge interface used by the network setup helper

### `ansible/vaulted_secrets.example.yml`

Used by:

- `playbooks/database_node_setup.yml`

Purpose:

- example secret surface for the database and application integration workflow

Variables:

- `pkiserver_token`: root or administrative token for the PKI Vault
- `vaultserver_token`: root or administrative token for the secrets Vault
- `kc_db_user`: Keycloak database username
- `kc_db_password`: Keycloak database password
- `kc_db_name`: Keycloak database name
- `kc_db_create`: toggle for Keycloak database creation flow
- `stripe_secrets_data`: KV payload for billing-related secrets
- `openai_secrets_data`: KV payload for AI-related secrets
- `sso_secrets_data`: KV payload for SSO secrets
- `queue_secrets_data`: KV payload for queue credentials

### `ansible/playbooks/rke2_join_info.example.yml`

Used by:

- `tasks/setup_rke2_worker.yml`

Variables:

- `rke2_server_ip`: RKE2 control-plane endpoint
- `rke2_join_token`: worker join token

## Common Inline Variables

Several playbooks define the same local defaults:

- `timezone`
- `ntp_servers`

These are consumed by:

- `tasks/sync_system_clock.yml`

## PKI Playbook Variables

`playbooks/pki_server_setup.yml` introduces PKI-specific paths and certificate subject data.

Path variables:

- `server_csr_conf_src_path`
- `cert_work_dir`
- `vault_tls_dir`
- `ca_key_path`
- `ca_cert_path`
- `server_key_path`
- `ca_csr_path`
- `server_csr_path`
- `server_cert_path`
- `server_conf_path`

Certificate subject variables:

- `ca_subj`
- `server_subj`
- `server_sans`

These drive the self-hosted PKI Vault bootstrap and server certificate generation steps.

## Database Playbook Variable Model

`playbooks/database_node_setup.yml` is the largest variable surface in the subtree.

### Connection and Cluster Context

- `kube_api_url`: API endpoint used to configure Vault Kubernetes auth
- `kube_issuer`: Kubernetes issuer string used by Vault auth configuration
- `vault_servers`: list of Vault endpoints that should have Kubernetes auth enabled

Each `vault_servers` entry contains:

- `hostname`
- `vault_address`

### `issuer_definitions`

Purpose:

- declare cert-manager issuers backed by the PKI Vault and the certificate requests associated with each issuer

Each issuer entry can contain:

- `name`
- `namespace`
- `type`
- `ressource_directory`
- `intermediate_cert_name`
- `issuer_service_account`
- `allowed_domains`
- `allow_subdomains`
- `pki_server_url`
- `pki_server_signing_path`
- `cert_manager_namespace`
- `cert_manager_service_account`
- `vault_server_hostname`
- `kube_issuer`
- `certificate_requests`

Each `certificate_requests` entry can contain:

- `certificate_name`
- `common_name`
- `requested_domains`
- `ip_sans`
- `usage`

### `gateway_definitions`

Purpose:

- declare gateway listeners, TLS settings, and route attachments for each exposed service area

Each gateway entry can contain:

- `name`
- `namespace`
- `pki_root_ca_path`
- `ressource_directory`
- `mtls_secret_name`
- `cp_tls_secret_name`
- `dp_tls_secret_name`
- `external_ip`
- `listeners`
- `routes`

Each `listeners` entry can contain:

- `name`
- `port`
- `protocol`
- `hostname`
- `mode`
- `tls_secret_name`

Each `routes` entry can contain:

- `name`
- `type`
- `parent_listener`
- `match_path`
- `rewrite_path`
- `backends`

### `database_definitions`

Purpose:

- declare CNPG cluster instances and their bootstrap behavior

Each database entry can contain:

- `name`
- `custom_image`
- `namespace`
- `tls_secret_name`
- `url`
- `port`
- `replicas`
- `vault_secured`
- `restore_from_backup`
- `postInitApplicationSQL`
- `extensions`

### `secret_base_path`

Purpose:

- root logical namespace used by the secret-registration flow

### `secret_definitions`

Purpose:

- declare secrets engines and logical secrets to create in the secrets Vault

Each entry can contain:

- `name`
- `type`
- `data`
- `key_type`
- `config`
- `db_url`
- `db_port`
- `db_name`
- `credentials_namespace`
- `roles`

The current file models:

- KV secrets
- a transit key
- a database secret engine with generated roles

### `app_definitions`

Purpose:

- define which Kubernetes service accounts should receive which Vault capabilities

Each app entry contains:

- `name`
- `namespace`
- `service_account_name`
- `permissions`

Each permission entry contains:

- `secret`
- `access`

## Runtime Environment Variables

Outside Ansible variable files, the local lab also uses:

- `LAB_BRIDGE_IFACE`: selected by `vagrant/Vagrantfile` for the gateway public bridge
- `ANSIBLE_VAULT_PASSWORD_FILE`: optional file path passed from Vagrant into the database-node Ansible provisioner

## Review Guidance

When adjusting the lab, start variable review in this order:

1. variable files in `ansible/`
2. inline structures inside `database_node_setup.yml`
3. Vagrant environment variables
4. resource templates under `ansible/ressources/k8s/templates/`
