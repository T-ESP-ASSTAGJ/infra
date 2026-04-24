# Architecture

This document summarizes the lab topology preserved under `rnd/` and the responsibilities of each node.

## Topology

| Node | Source | Primary role |
| --- | --- | --- |
| `gateway` | `vagrant/Vagrantfile` | OpenBSD edge node, DHCP, DNS, packet filter, BGP, SSH jump host |
| `pkiserver` | `ansible/playbooks/pki_server_setup.yml` | Dedicated Vault instance used as the platform PKI authority |
| `vaultserver` | `ansible/playbooks/vault_server_setup.yml` | Separate Vault instance used for secrets and dynamic credentials |
| `masternode` | `ansible/playbooks/master_node_setup.yml` | RKE2 control plane, Helm bootstrap, storage, networking, monitoring operator |
| `backendnode` | `ansible/playbooks/backend_node_setup.yml` | RKE2 worker-style node plus cert-manager and Vault agent support |
| `databasenode` | `ansible/playbooks/database_node_setup.yml` | Main integration node for certificates, gateways, CNPG, Bytebase, and secret wiring |
| `frontendnode` | playbook present, Vagrant block commented out | Additional worker role draft |
| `apinode` | playbook present, Vagrant block commented out | Additional worker role draft |

## Vault Split

Two different Vault deployments are modeled in this lab.

### PKI Vault

The PKI node is not just a generic VM. It installs Vault, initializes it, unseals it, and configures certificate authorities:

- root CA
- internal intermediate CA
- Kubernetes intermediate CA

Relevant files:

- [../ansible/playbooks/pki_server_setup.yml](../ansible/playbooks/pki_server_setup.yml)
- [../ansible/tasks/vault/setup_root_ca.yml](../ansible/tasks/vault/setup_root_ca.yml)
- [../ansible/tasks/vault/setup_intermediate_ca.yml](../ansible/tasks/vault/setup_intermediate_ca.yml)
- [../ansible/tasks/vault/setup_kubernetes_intermediate_ca.yml](../ansible/tasks/vault/setup_kubernetes_intermediate_ca.yml)

This node is also the issuer backend used by cert-manager integration. The issuer configuration work happens in:

- [../ansible/tasks/universal/configure_certificate_issuer.yml](../ansible/tasks/universal/configure_certificate_issuer.yml)

### Secrets Vault

The separate Vault node is used as the secret store and dynamic credential engine. Its TLS material is minted by the PKI node before the Vault service is configured.

Relevant files:

- [../ansible/playbooks/vault_server_setup.yml](../ansible/playbooks/vault_server_setup.yml)
- [../ansible/tasks/vault/generate_vault_certs.yml](../ansible/tasks/vault/generate_vault_certs.yml)
- [../ansible/tasks/universal/configure_vault_secrets.yml](../ansible/tasks/universal/configure_vault_secrets.yml)
- [../ansible/tasks/universal/configure_vault_permissions.yml](../ansible/tasks/universal/configure_vault_permissions.yml)

The practical split is:

- `pkiserver` signs certificates and exposes PKI roles
- `vaultserver` stores application secrets and can issue dynamic database credentials

## Kubernetes Layer

The RKE2 control plane is bootstrapped on `masternode`, then additional nodes consume the worker configuration.

Cluster bootstrap components include:

- RKE2 and Cilium
- Prometheus operator
- Longhorn
- cert-manager support
- BGP-related manifests

Relevant files:

- [../ansible/playbooks/master_node_setup.yml](../ansible/playbooks/master_node_setup.yml)
- [../ansible/tasks/setup_rke2_master.yml](../ansible/tasks/setup_rke2_master.yml)
- [../ansible/tasks/setup_rke2_worker.yml](../ansible/tasks/setup_rke2_worker.yml)
- [../ansible/tasks/setup_cilium_bgp.yml](../ansible/tasks/setup_cilium_bgp.yml)
- [../ansible/tasks/setup_longhorn.yml](../ansible/tasks/setup_longhorn.yml)

## Service Integration Layer

The database playbook is the heaviest orchestration layer in the subtree. It wires together:

- Vault Kubernetes auth
- cert-manager issuers and certificates
- gateway and route manifests
- CNPG database clusters
- Bytebase
- monitoring-facing certificates and gateways
- secret registration back into Vault

Relevant files:

- [../ansible/playbooks/database_node_setup.yml](../ansible/playbooks/database_node_setup.yml)
- [../ansible/tasks/universal/configure_vault_auth.yml](../ansible/tasks/universal/configure_vault_auth.yml)
- [../ansible/tasks/universal/configure_gateway_and_routes.yml](../ansible/tasks/universal/configure_gateway_and_routes.yml)
- [../ansible/tasks/universal/configure_database.yml](../ansible/tasks/universal/configure_database.yml)

## Important Caveats

- This subtree captures working ideas and orchestration drafts, not a production-ready deployment.
- Some Kubernetes values files are large vendor-derived baselines with only partial local customization.
- Placeholder credentials and endpoints remain in several manifests and examples by design.
- Local Vault initialization still writes key material during execution; those generated files are intentionally ignored.
