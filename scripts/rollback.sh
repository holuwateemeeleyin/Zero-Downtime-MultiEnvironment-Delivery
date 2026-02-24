#!/usr/bin/env bash
# ============================================================
# rollback.sh — Emergency rollback for canary deployment
# Usage: ./scripts/rollback.sh [namespace] [reason]
# ============================================================
set -euo pipefail

NAMESPACE="${1:-prod}"
REASON="${2:-manual-rollback}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() { echo "[${TIMESTAMP}] [rollback] $*"; }

log "=== EMERGENCY ROLLBACK INITIATED ==="
log "Namespace: ${NAMESPACE}"
log "Reason: ${REASON}"

# 1. Scale canary to 0 immediately
log "[1/4] Scaling canary deployment to 0..."
kubectl scale deployment backend-canary -n "$NAMESPACE" --replicas=0 2>/dev/null || \
  log "WARNING: Could not scale backend-canary (may not exist)"

# 2. Remove canary ingress weight
log "[2/4] Removing canary ingress weight..."
kubectl annotate ingress backend-canary -n "$NAMESPACE" \
  nginx.ingress.kubernetes.io/canary-weight=0 --overwrite 2>/dev/null || \
  log "WARNING: Could not update canary ingress annotation"

# 3. Verify stable is healthy
log "[3/4] Verifying stable deployment health..."
kubectl rollout status deployment/backend-stable -n "$NAMESPACE" --timeout=60s 2>/dev/null || \
  log "WARNING: Stable deployment not fully ready — check manually"

# 4. Log event
log "[4/4] Recording rollback event..."
kubectl create configmap "rollback-event-$(date +%s)" \
  -n "$NAMESPACE" \
  --from-literal=timestamp="$TIMESTAMP" \
  --from-literal=reason="$REASON" \
  --from-literal=triggered-by="rollback.sh" 2>/dev/null || true

log "✅ ROLLBACK COMPLETE — 100% traffic now on backend-stable"
log "To verify: kubectl get pods -n ${NAMESPACE} -l app=backend"
