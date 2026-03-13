# Jamly Infrastructure V2 — Plan

## Architecture

```
Internet → Cloudflare (proxy) → Azure App Gateway (TLS, L7)
         → K8s Worker NodePort → Cilium Gateway API
         → jamly-api  (Symfony + Mercure/FrankenPHP)
         → jamly-web  (Next.js)
         → jamly-redis (Redis)
         → Azure PostgreSQL Flexible Server (provider-managed)
```

**GitOps:** ArgoCD watches `k8s/` in this repo. No imperative `kubectl apply` in CI.

### Technology choices

| Concern | Choice | Rationale |
|---|---|---|
| CNI | Cilium (existing) | Already installed, kube-proxy replacement, Hubble, network policies. Flannel would be a downgrade. |
| Ingress | Cilium Gateway API | `kubernetes/ingress-nginx` EOL March 2026. Cilium already implements Gateway API natively — no extra component needed. |
| GitOps | ArgoCD | Sufficient for 1 cluster. Rancher (~1GB RAM, multi-cluster overhead) is overkill. |
| Secrets | ESO + Azure Key Vault | Key Vault already exists. Secrets never in git. |
| DB | Azure PostgreSQL (provider) | Managed backups, ~€15/month. Self-hosted DB is V3. |
| LB | Azure App Gateway (provider) | L7, host-based routing, TLS termination, WAF-ready. |

---

## Target Repository Structure

```
infra/
  terraform/
    V2/
      persistent/       ← VNet, NSG, App Gateway, Cloudflare DNS, PostgreSQL, Key Vault
      ephemeral/        ← K8s VMs (control plane + 1 worker), Ansible inventory generation
  ansible/
    roles/
      common/             (existing)
      k8s_control_plane/  (existing)
      k8s_worker/         (new)
      argocd/             (new)
    playbooks/
      full_setup.yml      (update run order)
      k8s_worker.yml      (new)
      argocd.yml          (new)
  k8s/
    argocd/apps/          ← App of Apps CRDs
    apps/
      gateway/            ← Cilium GatewayClass + Gateway + HTTPRoutes
      eso/                ← External Secrets Operator (Helm)
      redis/
      api/
      web/
    base/
      namespaces.yaml
      network-policies.yaml
  .github/workflows/
    infrastructure.yml    (fix + split persistent/ephemeral jobs)
    ansible.yml           (new)
    k8s-sync.yml          (new — GitOps image tag update loop)
```

---

## Phase 0: Split Terraform V2 → `persistent/` + `ephemeral/`

**Why split?** `terraform destroy` on compute should never touch the database or network.
- `persistent/` = VNet, App Gateway, PostgreSQL, DNS, Key Vault → destroyed manually only
- `ephemeral/` = K8s VMs → safe to tear down and recreate

Docs: [Terraform backends](https://developer.hashicorp.com/terraform/language/backend/azurerm)

### `persistent/main.tf` — what to create

- **Resource Group** `V2-jamly-persistent-rg`
- **VNet** `jamlyvnet` `10.0.0.0/16` with two subnets:
  - `appgw-subnet` `10.0.1.0/24` (App Gateway requires its own dedicated subnet)
  - `nodes-subnet` `10.0.2.0/23` (K8s VMs, 512 IPs)
- **NSG** for nodes-subnet:
  - Inbound: SSH/22 from management IP, HTTP/30080 from appgw-subnet, UDP/8472 intra-subnet (Cilium VXLAN), K8s ports intra-subnet (6443, 10250, 2379-2380)
- **Azure Application Gateway** Standard_v2:
  - Static public IP → Cloudflare DNS
  - HTTPS listener with Cloudflare origin cert (from Key Vault)
  - Backend pool → worker node private IP on NodePort 30080
  - Health probe: HTTP GET `/` on port 30080
  - Docs: [App Gateway overview](https://learn.microsoft.com/en-us/azure/application-gateway/overview)
- **Azure Key Vault** — Cloudflare origin cert + app secrets
- **Cloudflare DNS** — A records for `staging.jamly.eu` and `api-staging.jamly.eu` → App Gateway public IP
- **Azure PostgreSQL Flexible Server** v16 `B_Standard_B1ms`:
  - In persistent RG (protected from ephemeral destroy)
  - Firewall: allow `10.0.2.0/23` only
- **Outputs**: VNet/subnet IDs, App Gateway public IP, PostgreSQL FQDN

> Cloudflare API token and PostgreSQL password must come from GitHub secrets, never `.tfvars`.

### `ephemeral/main.tf` — what to create

- **Resource Group** `V2-jamly-ephemeral-rg`
- **Control plane VM** `jamlycp` — move existing VM here (`Standard_F4s_v2`, Ubuntu 22.04, public IP for Ansible SSH)
- **Worker VM** `jamlyw1` — new (`Standard_B2s` 2 vCPU/4GB ~€30/month, private IP only)
- **`local_file`** generates `ansible/inventory/hosts.ini` from template:

```ini
[k8s_control_plane]
jamlycp ansible_host=${cp_public_ip} k8s_advertise_address=${cp_private_ip}

[k8s_workers]
jamlyw1 ansible_host=${w1_private_ip} ansible_ssh_common_args='-o ProxyJump=tfou3lik@${cp_public_ip}'

[azure_vms:children]
k8s_control_plane
k8s_workers

[azure_vms:vars]
ansible_user=tfou3lik
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

Workers have no public IP — Ansible reaches them via SSH ProxyJump through the control plane.

---

## Phase 1: Kubernetes Worker Node

### What is a worker node?

A K8s cluster has two roles:
- **Control plane** (already running): the brain — API server, scheduler, etcd. Decides *where* pods run. No app pods here.
- **Worker node**: runs actual workloads. The `kubelet` agent receives instructions from the control plane and starts containers via containerd. Workers expose NodePort services (30000-32767) for external traffic.

Without workers, no app pods can be scheduled.

Docs: [Kubernetes nodes](https://kubernetes.io/docs/concepts/architecture/nodes/), [kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/)

### New Ansible role: `k8s_worker`

Reuse existing tasks from `k8s_control_plane` verbatim (same base setup required):
- `prerequisites.yml` — swap disabled, kernel modules, sysctl
- `container_runtime.yml` — containerd
- `kubernetes.yml` — kubelet/kubeadm/kubectl v1.29

New `tasks/join.yml`:
1. Check `/etc/kubernetes/kubelet.conf` → skip if already joined (idempotent)
2. `slurp` `/root/k8s-worker-join-command.sh` from the control plane host
3. Execute `kubeadm join`
4. UFW: open 10250 (Kubelet API), 30000-32767 (NodePort range)

Update `full_setup.yml` order: `common` → `k8s_control_plane` → `k8s_worker` → `argocd`

**Verify:** `kubectl get nodes -o wide` → `jamlycp` (control-plane) + `jamlyw1` (worker), both `Ready`

---

## Phase 2: Cilium Gateway API

### Why not Nginx Ingress?

`kubernetes/ingress-nginx` (community) EOL is March 2026 — no more security patches.
Reference: [Ingress NGINX Retirement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)

### Why Cilium Gateway API?

Cilium 1.18.6 is already installed. It natively implements [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) (GA since late 2023) via its built-in Envoy proxy. **No additional component to deploy.**

Advantages:
- Zero extra deployment
- eBPF-integrated: network policies apply at the kernel level
- Vendor-neutral, no annotation soup
- Future-proof (Gateway API is actively evolving; classic `Ingress` is feature-frozen)

Docs: [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)

### What is the Gateway API?

Replaces classic `Ingress` with three resources:
- **`GatewayClass`** — which controller owns Gateways (value: `cilium`)
- **`Gateway`** — a listener on the cluster edge, creates a K8s Service (NodePort here)
- **`HTTPRoute`** — routing rules: hostname/path → backend service (written per app)

### Enable in Cilium

Update `ansible/roles/k8s_control_plane/tasks/cni.yml` — add to Cilium install args:
```
--set gatewayAPI.enabled=true
--set gatewayAPI.serviceType=NodePort
```

Install Gateway API CRDs first:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

### Gateway resource (`k8s/apps/gateway/gateway.yaml`)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: jamly-gateway
  namespace: kube-system
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
```

Cilium creates a NodePort Service. Note the NodePort number, then update the App Gateway backend pool in `persistent/` to `worker-private-ip:NodePort`, and `terraform apply`.

Flow: `App Gateway → worker:NodePort → Cilium eBPF → Service → Pod`

---

## Phase 3: ArgoCD (GitOps)

### What is GitOps / ArgoCD?

**GitOps**: Git is the source of truth for the desired cluster state. A controller watches the repo and reconciles the cluster automatically — no manual `kubectl apply`.

**ArgoCD** is that controller. It:
- Watches a Git directory for K8s manifests
- Diffs live state vs. desired state
- Auto-syncs on commit (with `selfHeal: true`)
- Provides a web UI for sync status and rollback history

Docs: [ArgoCD](https://argo-cd.readthedocs.io/en/stable/getting_started/)

### App of Apps pattern

One root `Application` CRD points to `k8s/argocd/apps/` which contains more `Application` CRDs — ArgoCD bootstraps the whole stack from a single apply.

```
root-app → k8s/argocd/apps/
             ├── base-app.yaml        → k8s/base/
             ├── gateway-app.yaml     → k8s/apps/gateway/
             ├── eso-app.yaml         → k8s/apps/eso/
             ├── redis-app.yaml       → k8s/apps/redis/
             ├── api-app.yaml         → k8s/apps/api/
             └── web-app.yaml         → k8s/apps/web/
```

All apps: `syncPolicy.automated.selfHeal: true`, `prune: true`

Docs: [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

### New Ansible role: `argocd`

Runs on the control plane host:
1. Check if `argocd` namespace exists → skip if installed (idempotent)
2. Download pinned ArgoCD install manifest (e.g., `v2.11.3`)
3. `kubectl apply -f argocd-install.yaml`
4. `kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s`
5. Apply `k8s/argocd/apps/root-app.yaml`
6. Print initial admin password (one-time)

---

## Phase 4: Kubernetes Manifests

### Namespaces (`k8s/base/namespaces.yaml`)

`jamly-api`, `jamly-web`, `jamly-redis`

Docs: [Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

### Network Policies (`k8s/base/network-policies.yaml`)

Default: deny all ingress and egress per namespace. Then explicit allows:

| Namespace | Allow ingress from | Allow egress to |
|---|---|---|
| `jamly-api` | Cilium Gateway service | PostgreSQL:5432, `jamly-redis`:6379 |
| `jamly-web` | Cilium Gateway service | `jamly-api`:80 |
| `jamly-redis` | `jamly-api` only | — |

Cilium enforces these via eBPF. Docs: [Network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

### Secret Management — External Secrets Operator (`k8s/apps/eso/`)

**Never commit K8s Secrets to git** — they are only base64-encoded, not encrypted.

**ESO** connects to Azure Key Vault and syncs secrets into K8s `Secret` objects on a schedule. The secrets themselves never touch the repo.

Components:
- `ClusterSecretStore` — points to Key Vault, authenticates via service principal
- `ExternalSecret` (per app) — "create K8s Secret `api-secrets` from Key Vault keys `DATABASE_URL`, `APP_SECRET`, `MERCURE_JWT_SECRET`"

Docs: [External Secrets Operator](https://external-secrets.io/latest/), [Azure Key Vault provider](https://external-secrets.io/latest/provider/azure-key-vault/)

### Redis (`k8s/apps/redis/`)

Cache + Mercure pub/sub broker. Uses `StatefulSet` (not `Deployment`) for stable pod identity on restart.

- Image: `redis:7-alpine`, 1 replica
- Resources: `requests: cpu=50m, memory=64Mi` / `limits: cpu=200m, memory=256Mi`
- Service: ClusterIP port 6379 (internal only)
- No PVC for staging (in-memory; cache loss on restart acceptable)

Docs: [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

### API — Symfony + Mercure (`k8s/apps/api/`)

FrankenPHP bundles Caddy + Mercure + PHP. Handles REST and SSE connections.

- `ExternalSecret` → syncs `DATABASE_URL`, `APP_SECRET`, `MERCURE_JWT_SECRET`
- `Deployment` 1 replica (staging):
  - Resources: `requests: cpu=250m, memory=512Mi` / `limits: cpu=1, memory=1Gi`
  - Liveness/readiness probe: HTTP GET `/api/docs` (300s initial delay)
- `Service`: ClusterIP port 80
- `HTTPRoute` on `api-staging.jamly.eu` → `jamly-gateway`, with SSE timeout configured via `HTTPRoute.spec.rules[].timeouts.backendRequest`
- `HPA`: min 1 / max 3, CPU 70%

Docs: [HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/), [Mercure](https://mercure.rocks/docs/getting-started)

### Web — Next.js (`k8s/apps/web/`)

- `ConfigMap` with `NEXT_PUBLIC_API_URL`
- `Deployment` 1 replica:
  - Resources: `requests: cpu=100m, memory=256Mi` / `limits: cpu=500m, memory=512Mi`
- `Service`: ClusterIP port 3000
- `HTTPRoute` on `staging.jamly.eu` → `jamly-gateway`
- `HPA`: min 1 / max 3, CPU 70%

---

## Phase 5: GitHub Actions

### Fix `infrastructure.yml`

Current problems:
- References `terraform/environments/${{ inputs.environment }}` — path doesn't exist
- DigitalOcean secrets leftover in env block

Fix:
- Two jobs: `persistent` and `ephemeral` with correct `working-directory`
- Azure OIDC credentials (no long-lived secrets): [Azure OIDC for GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)
- Azure Blob Storage backend for tfstate (not committed to git): [AzureRM backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)

### New `ansible.yml`

- Trigger: `workflow_dispatch` or after successful `infrastructure.yml`
- Inputs: `playbook` (name), `environment`
- Sets up SSH key from GitHub secret, runs the playbook

### New `k8s-sync.yml` (GitOps image update)

App repo CI → calls this workflow with `image_tag` → updates tag in `k8s/apps/api/kustomization.yaml` → commits → ArgoCD detects → rolling deploy.

```
Push app code → CI builds image → calls infra repo → git commit → ArgoCD sync → K8s rolling update
```

No manual `kubectl set image`. Docs: [Kustomize images](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/images/)

---

## Execution Order

1. `terraform apply` **persistent** → network, App Gateway (backend empty), PostgreSQL, DNS
2. `terraform apply` **ephemeral** → VMs, generates `hosts.ini`
3. **Ansible** `full_setup.yml` → (control plane idempotent), join worker, install ArgoCD
4. Apply Gateway API CRDs → enable `gatewayAPI.enabled=true` in Cilium (re-run `cni.yml` or `helm upgrade`)
5. `kubectl apply -f k8s/apps/gateway/` → Cilium creates Gateway NodePort Service
6. `terraform apply` **persistent** again → update App Gateway backend pool with `worker-ip:NodePort`
7. **ArgoCD App of Apps** → deploys ESO, Redis, API, Web automatically

---

## Secrets Reference

| Secret | Stored in | Consumed via |
|---|---|---|
| Cloudflare API token | GitHub secret | `-var` flag in `infrastructure.yml` |
| Azure credentials | GitHub OIDC | Terraform provider |
| PostgreSQL admin password | Azure Key Vault | ESO → K8s Secret |
| `DATABASE_URL`, `APP_SECRET`, `MERCURE_JWT_SECRET` | Azure Key Vault | ESO `ExternalSecret` |
| SSH private key | GitHub secret | `ansible.yml` workflow |

---

## Verification Checklist

1. `kubectl get nodes -o wide` → `jamlycp` (control-plane) + `jamlyw1` (worker), both `Ready`
2. `cilium status` → all components healthy, Hubble enabled
3. `kubectl get gateways -A` → `jamly-gateway` `Ready`
4. Smoke test: `curl http://<worker-ip>:<gateway-nodeport>` → 200
5. ArgoCD UI accessible, App of Apps fully synced green
6. `kubectl get externalsecrets -A` → all `SecretSynced`
7. API pod `Running`, PostgreSQL connection OK in logs
8. `curl https://api-staging.jamly.eu/` → Symfony response
9. `curl https://staging.jamly.eu/` → Next.js response
10. Mercure SSE: `EventSource('https://api-staging.jamly.eu/.well-known/mercure?topic=test')` connects
