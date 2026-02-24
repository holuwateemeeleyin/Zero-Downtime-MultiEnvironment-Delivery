#!/usr/bin/env bash
# ============================================================
# evidence-pack.sh — Collect deployment evidence for review
# Captures: pod status, image versions, HPA, events,
#           policy outputs, chaos logs, and test results.
# Usage: ./scripts/evidence-pack.sh [namespace]
# ============================================================
set -euo pipefail

NAMESPACE="${1:-prod}"
TIMESTAMP=$(date +%Y%m%dT%H%M%S)
EVIDENCE_DIR="evidence/pack-${TIMESTAMP}"
mkdir -p "$EVIDENCE_DIR"

log() { echo "[evidence-pack] $*"; }

log "Collecting evidence for namespace=${NAMESPACE} at ${TIMESTAMP}"
log "Output directory: ${EVIDENCE_DIR}"

# ─── Cluster State ───────────────────────────────────────────
log "[1/7] Collecting pod status..."
kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null \
  > "${EVIDENCE_DIR}/pods.txt" || echo "kubectl unavailable" > "${EVIDENCE_DIR}/pods.txt"

log "[2/7] Collecting deployment status..."
kubectl get deployments -n "$NAMESPACE" -o yaml 2>/dev/null \
  > "${EVIDENCE_DIR}/deployments.yaml" || echo "kubectl unavailable" > "${EVIDENCE_DIR}/deployments.yaml"

log "[3/7] Collecting HPA status..."
kubectl get hpa -n "$NAMESPACE" -o wide 2>/dev/null \
  > "${EVIDENCE_DIR}/hpa.txt" || echo "kubectl unavailable" > "${EVIDENCE_DIR}/hpa.txt"

log "[4/7] Collecting recent events..."
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null \
  > "${EVIDENCE_DIR}/events.txt" || echo "kubectl unavailable" > "${EVIDENCE_DIR}/events.txt"

log "[5/7] Collecting ingress status..."
kubectl get ingress -n "$NAMESPACE" -o wide 2>/dev/null \
  > "${EVIDENCE_DIR}/ingress.txt" || echo "kubectl unavailable" > "${EVIDENCE_DIR}/ingress.txt"

# ─── Policy Evidence ─────────────────────────────────────────
log "[6/7] Collecting Kyverno policy report..."
kubectl get polr -n "$NAMESPACE" -o wide 2>/dev/null \
  > "${EVIDENCE_DIR}/kyverno-policy-report.txt" || \
  echo "Kyverno not installed / no policy reports" > "${EVIDENCE_DIR}/kyverno-policy-report.txt"

# ─── Chaos Evidence ──────────────────────────────────────────
log "[7/7] Collecting chaos experiment logs..."
if ls evidence/chaos-*.log >/dev/null 2>&1; then
  cp evidence/chaos-*.log "${EVIDENCE_DIR}/" 2>/dev/null || true
else
  echo "No chaos logs found (run chaos experiments first)" > "${EVIDENCE_DIR}/chaos-summary.txt"
fi

# ─── Image Versions ──────────────────────────────────────────
log "Recording deployed image versions..."
{
  echo "=== Image Versions: ${TIMESTAMP} ==="
  kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' 2>/dev/null || \
    echo "backend:  ghcr.io/shopmicro/backend:v1 (simulated)"
} > "${EVIDENCE_DIR}/image-versions.txt"

# ─── Summary Manifest ────────────────────────────────────────
cat > "${EVIDENCE_DIR}/SUMMARY.md" <<EOF
# Evidence Pack — ${TIMESTAMP}

**Namespace**: \`${NAMESPACE}\`
**Generated**: ${TIMESTAMP}

## Files Collected
| File | Contents |
|------|----------|
| pods.txt | Pod status and node placement |
| deployments.yaml | Full deployment specs |
| hpa.txt | HPA targets and current replicas |
| events.txt | Recent cluster events |
| ingress.txt | Ingress routing table |
| kyverno-policy-report.txt | Policy compliance report |
| chaos-*.log | Chaos experiment results |
| image-versions.txt | Deployed image tags |

## SLO Summary
- Error rate gate: < 1%
- p99 latency gate: < 500ms
- Availability gate: > 99.5%

## Canary Status
$(kubectl get ingress backend-canary -n "$NAMESPACE" \
  -o jsonpath='Canary weight: {.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}%' 2>/dev/null || \
  echo "Canary ingress not active")
EOF

# ─── Tar archive ─────────────────────────────────────────────
tar -czf "evidence-pack-${TIMESTAMP}.tar.gz" -C "$(dirname "$EVIDENCE_DIR")" "$(basename "$EVIDENCE_DIR")"

log "✅ Evidence pack created: evidence-pack-${TIMESTAMP}.tar.gz"
log "   Directory: ${EVIDENCE_DIR}/"
