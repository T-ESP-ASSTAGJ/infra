# Playbook Reference

This document describes every Ansible playbook preserved under `rnd/ansible/playbooks/`, the setup tasks each playbook pulls in, and the main assumptions behind each execution path.

## Shared Conventions

Most playbooks share a few conventions:

- target group: `hosts: all` with the effective host selected by the inventory group you run against
- privilege level: `become: yes`
- base node preparation: `sync_system_clock.yml` and `install_linux_utils.yml` are used by most Linux-oriented playbooks
- cluster-aware playbooks export `KUBECONFIG=/etc/rancher/rke2/rke2.yaml`
- Vault-aware playbooks export `VAULT_ADDR` that matches the Vault instance they expect to talk to

## Entry Points

### `gateway_server_setup.yml`

Purpose:

- configure the OpenBSD gateway node for DHCP client/server behavior, DNS, routing, packet filtering, and BGP

Variable inputs:

- [../ansible/network_vars.yml](../ansible/network_vars.yml)
- inline `timezone`
- inline `ntp_servers`

Included setup tasks:

- `tasks/gateway/setup_dhcp_client.yml`
- `tasks/gateway/setup_default_gateway.yml`
- `tasks/gateway/install_BSD_utils.yml`
- `tasks/gateway/setup_dns_server.yml`
- `tasks/gateway/setup_dhcp_server.yml`
- `tasks/gateway/setup_packet_filter.yml`
- `tasks/gateway/setup_bgp.yml`

Important outputs and side effects:

- configures `unbound`, `dhcpd`, PF rules, and routing behavior
- uses handlers to enable DNS and DHCP services and apply PF configuration

### `pki_server_setup.yml`

Purpose:

- bootstrap the dedicated PKI Vault node and build the certificate authority hierarchy

Variable inputs:

- inline `timezone`
- inline `ntp_servers`
- TLS workspace paths such as `cert_work_dir` and `vault_tls_dir`
- PKI subject definitions in `ca_subj`, `server_subj`, and `server_sans`

Included setup tasks:

- `tasks/sync_system_clock.yml`
- `tasks/install_linux_utils.yml`
- `tasks/vault/install_vault.yml`
- `tasks/vault/setup_pki_certificates.yml`
- `tasks/vault/initiate_vault.yml`
- `tasks/vault/unseal_vault.yml`
- `tasks/vault/setup_root_ca.yml`
- `tasks/vault/setup_intermediate_ca.yml`
- `tasks/vault/setup_kubernetes_intermediate_ca.yml`

Important outputs and side effects:

- installs Vault on the PKI node
- generates local TLS for the PKI Vault service
- initializes and unseals the Vault instance
- creates root and intermediate PKI engines used by the rest of the lab

### `vault_server_setup.yml`

Purpose:

- bootstrap the separate Vault node used for secrets and dynamic credentials

Variable inputs:

- inline `timezone`
- inline `ntp_servers`
- `VAULT_ADDR=http://127.0.0.1:8200`

Included setup tasks:

- `tasks/sync_system_clock.yml`
- `tasks/install_linux_utils.yml`
- `tasks/vault/generate_vault_certs.yml` delegated to `pkiserver`
- `tasks/vault/install_vault.yml`
- `tasks/vault/configure_vault_tls.yml`
- `tasks/vault/initiate_vault.yml`
- `tasks/vault/unseal_vault.yml`

Important outputs and side effects:

- requests the Vault node certificate from the PKI node
- installs a second Vault instance distinct from the PKI Vault
- prepares the secret-management endpoint later used by database and app permission setup

### `master_node_setup.yml`

Purpose:

- bootstrap the RKE2 control plane and baseline cluster services

Variable inputs:

- inline `timezone`
- inline `ntp_servers`
- `KUBECONFIG=/etc/rancher/rke2/rke2.yaml`

Included setup tasks:

- `tasks/sync_system_clock.yml`
- `tasks/install_linux_utils.yml`
- `tasks/setup_rke2_master.yml`
- `tasks/install_helm.yml`
- `tasks/configure_fzf.yml`
- `tasks/monitoring/configure_prometheus_operator.yml`
- `tasks/setup_longhorn.yml`
- `tasks/setup_cilium_bgp.yml`

Important outputs and side effects:

- installs the control plane
- installs Helm
- deploys Prometheus operator, Longhorn, and Cilium BGP-related resources

### `backend_node_setup.yml`

Purpose:

- bootstrap a worker-style cluster node and install shared cluster-side integrations from the control plane

Variable inputs:

- inline `timezone`
- inline `ntp_servers`
- `KUBECONFIG=/etc/rancher/rke2/rke2.yaml`
- `VAULT_ADDR=https://127.0.0.1:8200`

Included setup tasks:

- `tasks/sync_system_clock.yml`
- `tasks/install_linux_utils.yml`
- `tasks/setup_rke2_worker.yml`
- `tasks/cert_manager/install_cert_manager.yml` delegated to `masternode`
- `tasks/vault_agent/setup_vault_agent.yml` delegated to `masternode`

Important outputs and side effects:

- joins the node to the RKE2 cluster
- ensures cert-manager and Vault agent components are installed from the control-plane context

### `database_node_setup.yml`

Purpose:

- orchestrate the highest-level integration flow across PKI, Vault, Kubernetes auth, gateways, databases, monitoring, and app permissions

Variable inputs:

- [../ansible/vaulted_secrets.example.yml](../ansible/vaulted_secrets.example.yml)
- inline `timezone`
- inline `ntp_servers`
- inline `kube_api_url`
- inline `kube_issuer`
- complex structures:
  - `vault_servers`
  - `issuer_definitions`
  - `gateway_definitions`
  - `database_definitions`
  - `secret_base_path`
  - `secret_definitions`
  - `app_definitions`

Included setup tasks:

- `tasks/sync_system_clock.yml`
- `tasks/install_linux_utils.yml`
- `tasks/setup_rke2_worker.yml`
- `tasks/universal/configure_vault_auth.yml`
- `tasks/universal/configure_certificate_issuer.yml`
- `tasks/universal/configure_gateway_and_routes.yml`
- `tasks/database/install_cnpg.yml` delegated to `masternode`
- `tasks/universal/configure_database.yml`
- `tasks/vault_agent/setup_vault_agent.yml` delegated to `masternode`
- `tasks/database/install_bytebase.yml` delegated to `masternode`
- `tasks/monitoring/install_grafana.yml` delegated to `masternode`
- `tasks/monitoring/install_openObserve.yml` delegated to `masternode`
- `tasks/universal/configure_vault_secrets.yml`
- `tasks/universal/configure_vault_permissions.yml`

Important outputs and side effects:

- configures Kubernetes auth against both Vault servers
- creates cert-manager issuers backed by the PKI Vault
- renders and applies gateway and route resources
- deploys CNPG and Bytebase
- seeds Vault with KV, transit, and database engines
- binds service-account permissions for applications such as `auth-server`, `api`, and workers

### `api_node_setup.yml`

Purpose:

- minimal worker-style node bootstrap for an API role

Variable inputs:

- inline `timezone`
- inline `ntp_servers`
- `KUBECONFIG=/etc/rancher/rke2/rke2.yaml`

Included setup tasks:

- `tasks/install_linux_utils.yml`
- `tasks/setup_rke2_worker.yml`

### `frontend_node_setup.yml`

Purpose:

- minimal worker-style node bootstrap for a frontend role

Included setup tasks:

- `tasks/install_linux_utils.yml`
- `tasks/setup_rke2_worker.yml`

### `rke2_join_info.example.yml`

Purpose:

- example data file consumed by `tasks/setup_rke2_worker.yml`

Main variables:

- `rke2_server_ip`
- `rke2_join_token`

## Setup Task Families

The task tree is organized by setup domain:

- `tasks/gateway/`: OpenBSD edge services and routing
- `tasks/vault/`: Vault installation, initialization, TLS, and PKI engine management
- `tasks/vault-auth/`: Vault policy and auth snippets related to PKI integration
- `tasks/vault_agent/`: Vault agent installation and integration
- `tasks/database/`: CNPG and Bytebase installation
- `tasks/monitoring/`: Prometheus operator wiring, Grafana, and OpenObserve
- `tasks/cert_manager/`: cert-manager installation support
- `tasks/universal/`: cross-cutting orchestration used mainly by `database_node_setup.yml`

## Resource and Template Usage

The playbooks rely heavily on files under `ansible/ressources/`:

- `ressources/k8s/templates/`: Jinja templates for issuers, certificates, gateways, routes, and database manifests
- `ressources/k8s/*/helm/`: values files for Helm-installed services
- `ressources/k8s/cilium/`, `cnpg/`, `metallb/`, `vault/`, `certmanager/`: static manifests or supporting resources
- `ressources/dhcp/`, `dns/`, `packetfilter/`, `bgp/`: gateway-side configuration files

When you review or promote a playbook, review both the task file and the resource/template directories it references.
