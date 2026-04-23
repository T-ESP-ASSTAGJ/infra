# R&D Workspace

This subtree captures infrastructure research and lab automation that has not been merged into the main repository layout.

The content is intentionally isolated under `rnd/` so it can be reviewed, iterated on, and promoted into the main stack later in smaller changes.

## What This Contains

The imported research models a self-hosted platform lab with:

- an OpenBSD gateway node that owns routing, DHCP, DNS, and packet filtering
- a dedicated PKI node running Vault as a certificate authority
- a separate Vault node for secrets and dynamic database credentials
- an RKE2 control-plane node plus worker-style application nodes
- Kubernetes manifests and templates for cert-manager, CNPG, Longhorn, Prometheus, Grafana, OpenObserve, Bytebase, and gateway-related resources

The most useful starting points are:

- [docs/architecture.md](./docs/architecture.md)
- [docs/bootstrap.md](./docs/bootstrap.md)
- [docs/playbooks.md](./docs/playbooks.md)
- [docs/variables.md](./docs/variables.md)
- [ansible/README.md](./ansible/README.md)
- [vagrant/README.md](./vagrant/README.md)

## Included Areas

- `ansible/`: node bootstrap playbooks, shared tasks, Kubernetes manifests, and supporting templates
- `vagrant/`: local multi-node lab topology used to validate gateway, Vault, PKI, and cluster flows
- `docker/`: experimental image build used by the database cluster work

## Sanitization

This import excludes live credentials, generated certificates, database dumps, and machine-specific scratch files. Files that still require secrets or environment-specific values are represented with examples or placeholder values.

## Promotion Strategy

Treat this directory as a staging area:

1. validate and trim one capability at a time
2. move the pieces that are worth keeping into the main repo structure
3. replace remaining placeholders with environment-managed secrets
