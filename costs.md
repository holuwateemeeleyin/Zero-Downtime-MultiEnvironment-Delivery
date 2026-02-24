# ShopMicro — Environment Cost Analysis

**Date**: February 24, 2026  
**Platform**: Google Kubernetes Engine (GKE Autopilot equivalent pricing)  
**Baseline**: 3-environment setup (dev, staging, prod) on GKE Standard, us-central1

---

## 1. Per-Environment Resource Sizing

| Service | Dev | Staging | Prod |
|---------|-----|---------|------|
| backend | 1 replica, 100m CPU, 128Mi RAM | 2 replicas | 3–10 replicas (HPA) |
| ml-service | 1 replica, 150m CPU, 256Mi RAM | 2 replicas | 2–8 replicas (HPA) |
| frontend | 1 replica, 50m CPU, 64Mi RAM | 2 replicas | 2–4 replicas |
| Node type | e2-small (2 vCPU, 2GB) | e2-medium (2 vCPU, 4GB) | e2-standard-4 (4 vCPU, 16GB) |

---

## 2. Monthly Cost Estimate (GKE Standard, us-central1)

### Dev Environment
| Resource | Qty | Unit Price | Monthly |
|----------|-----|-----------|---------|
| e2-small node (1 node) | 730 hrs | $0.017/hr | $12.41 |
| Persistent disk (10GB SSD) | 1 | $0.17/GB/mo | $1.70 |
| Cluster management fee | — | $0.10/hr | $73.00 |
| Network egress (minimal) | 1 GB | $0.12/GB | $0.12 |
| **Dev Subtotal** | | | **$87.23/mo** |

### Staging Environment
| Resource | Qty | Unit Price | Monthly |
|----------|-----|-----------|---------|
| e2-medium nodes (2 nodes) | 730 hrs × 2 | $0.034/hr | $49.64 |
| Persistent disk (20GB SSD) | 1 | $0.17/GB/mo | $3.40 |
| Cluster management fee | — | $0.10/hr | $73.00 |
| Network egress (5GB) | 5 GB | $0.12/GB | $0.60 |
| **Staging Subtotal** | | | **$126.64/mo** |

### Prod Environment
| Resource | Qty | Unit Price | Monthly |
|----------|-----|-----------|---------|
| e2-standard-4 nodes (3 nodes) | 730 hrs × 3 | $0.134/hr | $293.58 |
| Persistent disk (50GB SSD) | 1 | $0.17/GB/mo | $8.50 |
| Cluster management fee | — | $0.10/hr | $73.00 |
| Network egress (50GB) | 50 GB | $0.12/GB | $6.00 |
| Cloud Load Balancer | 1 | $18.26/mo | $18.26 |
| **Prod Subtotal** | | | **$399.34/mo** |

### Total Platform Cost
| Environment | Monthly | Annual |
|-------------|---------|--------|
| Dev | $87.23 | $1,046.76 |
| Staging | $126.64 | $1,519.68 |
| Prod | $399.34 | $4,792.08 |
| **Total** | **$613.21** | **$7,358.52** |

---

## 3. Before / After HPA Optimization

### Before (Fixed Replicas)
| Service | Replicas | CPU/mo | Mem/mo | Cost/mo |
|---------|----------|--------|--------|---------|
| backend | 5 (fixed) | 500m × 5 | 256Mi × 5 | ~$62 |
| ml-service | 4 (fixed) | 750m × 4 | 512Mi × 4 | ~$58 |
| **Total** | 9 pods | | | **~$120/mo** |

### After (HPA Tuned to 60% CPU Target)
| Service | Min→Max | Avg Replicas | CPU/mo | Mem/mo | Cost/mo |
|---------|---------|-------------|--------|--------|---------|
| backend | 2→10 | 3 (off-peak) | 300m avg | 384Mi avg | ~$37 |
| ml-service | 2→8 | 2.5 (avg) | 375m avg | 640Mi avg | ~$41 |
| **Total** | | 5.5 avg pods | | | **~$78/mo** |

**Savings: ~$42/month (35% reduction) in compute for the application layer.**

### Savings Breakdown
- Removed idle capacity during off-peak hours (22:00–06:00 UTC)
- HPA scale-down stabilization window: 300s prevents flapping
- CPU target 60% vs previous 80%: provides headroom without over-provisioning
- Memory target 75%: ML service benefits most (batch inference spikes)

---

## 4. Optimization Recommendations

### Short Term (Immediate)
1. **Spot/Preemptible nodes for dev**: Use preemptible e2-small → saves 60–80%
   - Dev cost: $87.23 → ~$32/mo
2. **Dev cluster scheduled downtime**: Shut down dev cluster nights/weekends (14h/day off)
   - Saves ~58% of node cost: $12.41 → ~$5.22/mo on nodes
3. **Shared staging/dev cluster**: Use namespaces instead of separate clusters
   - Save one cluster management fee: -$73/mo

### Medium Term
4. **GKE Autopilot for prod**: Pay only for requested CPU/memory, not node capacity
   - Estimate 40% savings on node costs at current workload profile
5. **Reserved instances (1-year)**: Commit to e2-standard-4 for prod nodes
   - ~37% discount on compute: $293 → ~$185/mo
6. **Cloud CDN for frontend**: Offload static assets, reduce egress costs
   - Frontend egress: ~80% reducible

### Long Term
7. **Regional cluster** (single-zone): For dev/staging, saves cross-zone egress
8. **Workload Identity**: Replace service account keys, reducing secret rotation overhead
9. **Multi-tenant cluster with namespace soft quotas**: Share node pool across dev/staging

---

## 5. Optimized Cost Projection

| Environment | Current | Optimized (6 months) |
|-------------|---------|---------------------|
| Dev | $87.23/mo | $22/mo |
| Staging | $126.64/mo | $80/mo |
| Prod | $399.34/mo | $268/mo |
| **Total** | **$613.21/mo** | **$370/mo** |

**Projected savings: ~$243/month (39.6% reduction) after optimizations.**

---

## 6. Cost Attribution Labels

All K8s resources are labeled with:
- `app.kubernetes.io/part-of: shopmicro`
- `env: <dev|staging|prod>`

This enables GKE Cost Attribution reports from the GCP Billing console,
broken down by namespace and label selector.
