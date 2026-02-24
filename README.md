# ShopMicro — Zero-Downtime Multi-Environment Delivery

**Extra Credit Assignment | Platform Engineering | February 2026**

---

## Quick Start

```bash
# Bootstrap (check deps, create namespaces, chmod scripts)
make bootstrap

# Local development
make docker-up        # Start all services via docker-compose
# Frontend: http://localhost:3000
# Backend:  http://localhost:8080
# ML:       http://localhost:5000

# Validate policies
make validate

# Deploy to staging
make deploy ENV=staging

# Run smoke tests
make smoke-test ENV=staging

# Collect evidence
make evidence-pack ENV=staging
```

## Developer CLI (make targets)

| Command | Description |
|---------|-------------|
| `make bootstrap` | Check tools, create namespaces, chmod scripts |
| `make validate` | Run conftest + kubectl dry-run policy checks |
| `make deploy ENV=<env>` | Apply all K8s manifests to target namespace |
| `make rollback ENV=<env>` | Emergency canary rollback |
| `make smoke-test ENV=<env>` | Smoke-test all service endpoints |
| `make evidence-pack ENV=<env>` | Collect evidence archive |
| `make chaos-pod-kill ENV=<env>` | Run pod-kill chaos experiment |
| `make chaos-network-latency ENV=<env>` | Run network-latency experiment |
| `make rotate-secrets ENV=<env>` | Rotate K8s secrets + rolling restart |
| `make cost-report` | Display cost analysis |
| `make docker-up` | Start local docker-compose stack |
| `make docker-down` | Stop local docker-compose stack |
| `make build` | Build all Docker images locally |

## Repository Structure

```
├── backend/                 Node.js Express service
├── ml-service/              Python Flask ML service
├── frontend/                React/Vite frontend
├── infra/
│   ├── k8s/                 Kubernetes manifests (stable, canary, hpa, ingress)
│   ├── networkpolicies/     Service-to-service NetworkPolicies
│   └── policies/            Kyverno ClusterPolicies + Conftest OPA rules
├── chaos/                   Chaos Mesh experiments + run script
├── scripts/                 promote, rollback, smoke-test, evidence-pack, rotate-secrets
├── .github/workflows/       CI (build+test+Trivy) + Progressive Deploy workflow
├── Makefile                 Developer CLI
├── docker-compose.yaml      Local dev stack
├── costs.md                 Cost analysis + optimization plan
└── EXTRA_CREDIT_REPORT.md   ← START HERE (required report)
```

## Environments

| Namespace | Purpose | Node Type |
|-----------|---------|-----------|
| `dev` | Development, feature testing | e2-small |
| `staging` | Integration, pre-production validation | e2-medium |
| `prod` | Production, canary rollouts | e2-standard-4 |

## Release Strategy: Canary

```
v2 image → backend-canary (1 pod, 20% traffic)
         → wait 5m
         → SLO gate: error_rate < 1%, p99 < 500ms, availability > 99.5%
         → PASS: promote (stable ← v2 image, canary scaled to 0)
         → FAIL: rollback (canary → 0, 100% on stable)
```

## Security Controls

- **NetworkPolicies**: deny-all + specific allow rules per service
- **Kyverno**: 5 ClusterPolicies enforcing labels, pinned tags, resource limits, non-root
- **Trivy**: Blocks CI on CRITICAL/HIGH CVEs (SARIF uploaded to GitHub Security)
- **Secret rotation**: `make rotate-secrets` with timestamp annotation evidence

## Key Files

- [`EXTRA_CREDIT_REPORT.md`](./EXTRA_CREDIT_REPORT.md) — Full assignment report
- [`costs.md`](./costs.md) — Cost analysis ($613 → $370/mo, -39.6%)
- [`scripts/promote.sh`](./scripts/promote.sh) — SLO-gated canary promotion
- [`infra/policies/kyverno/cluster-policies.yaml`](./infra/policies/kyverno/cluster-policies.yaml) — Admission policies
- [`chaos/run-chaos.sh`](./chaos/run-chaos.sh) — Chaos experiment runner
