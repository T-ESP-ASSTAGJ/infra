# Bootstrap Flow

This document describes the intended order of operations for the lab preserved under `rnd/`.

## Expected Inputs

Before running the lab, adapt these files and environment variables:

- [../ansible/vaulted_secrets.example.yml](../ansible/vaulted_secrets.example.yml)
- [../ansible/playbooks/rke2_join_info.example.yml](../ansible/playbooks/rke2_join_info.example.yml)
- [../ansible/network_vars.yml](../ansible/network_vars.yml)
- `LAB_BRIDGE_IFACE` for the gateway public bridge
- `ANSIBLE_VAULT_PASSWORD_FILE` if you want Vagrant to pass a vault password file into Ansible

## Recommended Order

1. Bring up the `gateway` node.
2. Bring up `pkiserver`.
3. Bring up `vaultserver`.
4. Bring up `masternode`.
5. Bring up worker-style nodes such as `backendnode`, then optional `frontendnode` and `apinode` if those VM blocks are enabled.
6. Bring up `databasenode` last, because it depends on the PKI, Vault, and cluster layers already being reachable.

## Why This Order Matters

### Gateway First

The gateway node provides the network assumptions used throughout the lab:

- DHCP and DNS
- packet filtering
- default routing
- BGP-related edge behavior
- forwarded SSH ports used as the access path to the other machines

### PKI Before Secrets Vault

The PKI node sets up the certificate authority hierarchy. The separate Vault node requests its TLS material from the PKI node before its own secure configuration is completed.

### Control Plane Before Service Integration

The database playbook assumes:

- Kubernetes is reachable
- cert-manager can be installed and configured
- Vault Kubernetes auth can be enabled against the running cluster
- manifests can be applied from the master node

That is why the control plane and shared cluster services should exist before the database integration layer is applied.

## Main Playbooks

| Order | Playbook | Purpose |
| --- | --- | --- |
| 1 | [../ansible/playbooks/gateway_server_setup.yml](../ansible/playbooks/gateway_server_setup.yml) | network edge and host access |
| 2 | [../ansible/playbooks/pki_server_setup.yml](../ansible/playbooks/pki_server_setup.yml) | PKI Vault plus root and intermediate CAs |
| 3 | [../ansible/playbooks/vault_server_setup.yml](../ansible/playbooks/vault_server_setup.yml) | secrets Vault with PKI-issued TLS |
| 4 | [../ansible/playbooks/master_node_setup.yml](../ansible/playbooks/master_node_setup.yml) | RKE2 control plane and base cluster services |
| 5 | [../ansible/playbooks/backend_node_setup.yml](../ansible/playbooks/backend_node_setup.yml) | worker-style cluster services and Vault agent setup |
| 6 | [../ansible/playbooks/database_node_setup.yml](../ansible/playbooks/database_node_setup.yml) | service certificates, gateways, databases, secret wiring |

## Local Validation Notes

- `frontend_node` and `api_node` playbooks exist, but the corresponding VM blocks are commented out in the current Vagrant file.
- Vault initialization writes key files locally during the first run; these files are excluded by `rnd/.gitignore`.
- Some service manifests still contain placeholders. Treat this subtree as a lab baseline, not an immediately deployable environment.
