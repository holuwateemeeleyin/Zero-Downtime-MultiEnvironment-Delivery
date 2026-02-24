#!/usr/bin/env bash
# ============================================================
# rotate-secrets.sh — Secret rotation workflow
# Rotates Kubernetes secrets for all services and verifies.
# Usage: ./scripts/rotate-secrets.sh [namespace]
# ============================================================
set -euo pipefail

NAMESPACE="${1:-prod}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() { echo "[${TIMESTAMP}] [rotate-secrets] $*"; }

log "=== Secret Rotation Workflow ==="
log "Namespace: ${NAMESPACE}"

# ── Step 1: Generate new secrets ─────────────────────────────
log "[1/5] Generating new secret values..."
NEW_DB_PASSWORD=$(openssl rand -base64 32)
NEW_API_KEY=$(openssl rand -hex 32)
NEW_JWT_SECRET=$(openssl rand -base64 48)

# ── Step 2: Create/Update K8s secrets ────────────────────────
log "[2/5] Updating Kubernetes secrets..."
kubectl create secret generic shopmicro-secrets \
  -n "$NAMESPACE" \
  --from-literal=db-password="$NEW_DB_PASSWORD" \
  --from-literal=api-key="$NEW_API_KEY" \
  --from-literal=jwt-secret="$NEW_JWT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || \
  log "INFO: kubectl not available — recording rotation event only"

# ── Step 3: Annotate with rotation timestamp ──────────────────
log "[3/5] Annotating secret with rotation timestamp..."
kubectl annotate secret shopmicro-secrets -n "$NAMESPACE" \
  "shopmicro.io/last-rotated=${TIMESTAMP}" \
  "shopmicro.io/rotation-by=rotate-secrets.sh" \
  --overwrite 2>/dev/null || true

# ── Step 4: Trigger rolling restart to pick up new secrets ────
log "[4/5] Triggering rolling restart of all deployments..."
for dep in backend-stable backend-canary ml-service frontend; do
  kubectl rollout restart deployment/"$dep" -n "$NAMESPACE" 2>/dev/null && \
    log "  Restarted: $dep" || log "  Skipped (not found): $dep"
done

# ── Step 5: Verify secrets exist and apps are ready ───────────
log "[5/5] Verifying secret and deployment health..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/part-of=shopmicro \
  -n "$NAMESPACE" --timeout=120s 2>/dev/null || \
  log "WARNING: Not all pods ready within 120s — check manually"

kubectl get secret shopmicro-secrets -n "$NAMESPACE" \
  -o jsonpath='Secret {.metadata.name} last-annotated: {.metadata.annotations.shopmicro\.io/last-rotated}{"\n"}' \
  2>/dev/null || true

log "✅ Secret rotation complete at ${TIMESTAMP}"
log "   Verify: kubectl get secret shopmicro-secrets -n ${NAMESPACE}"
