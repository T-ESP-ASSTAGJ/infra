# R&D Workspace

This subtree captures infrastructure research and lab automation that has not been merged into the main repository layout.

The content is intentionally isolated under `rnd/` so it can be reviewed, iterated on, and promoted into the main stack later in smaller changes.

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
