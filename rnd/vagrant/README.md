# Vagrant Lab

The Vagrant file models a local validation environment for the `rnd/` subtree.

## Defined Machines

- `gateway`: OpenBSD bastion, gateway, DHCP, DNS, packet filter, BGP
- `pki`: dedicated PKI Vault instance
- `vault`: separate secrets Vault instance
- `master_node`: RKE2 control plane
- `backend_node`: worker-style application node
- `database_node`: integration-heavy data and service node

Playbooks also exist for `frontend_node` and `api_node`, but their VM definitions are currently commented out in the Vagrantfile.

## Access Pattern

The gateway exposes forwarded ports that act as the access path to the other nodes:

- `3501`: database node
- `3502`: backend node
- `3503`: master node
- `3504`: api node
- `3505`: Vault node
- `3506`: PKI node
- `3507` and `3508`: monitoring-related forwards

## Useful Environment Variables

- `LAB_BRIDGE_IFACE`: host bridge interface used by the OpenBSD gateway public network
- `ANSIBLE_VAULT_PASSWORD_FILE`: optional path passed into the database-node Ansible provisioner

## Notes

- The Vagrant topology is a lab harness, not a production deployment model.
- Private network addressing and MAC assignments are hardcoded in the Vagrantfile and should be treated as local-lab defaults.
