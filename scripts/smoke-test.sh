#!/usr/bin/env bash
# ============================================================
# smoke-test.sh — Smoke tests for all ShopMicro services
# Usage: ./scripts/smoke-test.sh [base_url] [namespace]
# ============================================================
set -euo pipefail

BASE_URL="${1:-http://shopmicro.local}"
NAMESPACE="${2:-prod}"
FAILED=0
PASSED=0

log()  { echo "[smoke] $*"; }
pass() { echo "  ✅ PASS: $1"; ((PASSED++)); }
fail() { echo "  ❌ FAIL: $1"; ((FAILED++)); }

check_endpoint() {
  local name="$1" url="$2" expected_status="${3:-200}" expected_body="${4:-}"
  local http_status body
  http_status=$(curl -sf -o /tmp/smoke_body -w "%{http_code}" \
    --max-time 10 --retry 2 --retry-delay 2 "$url" 2>/dev/null || echo "000")
  body=$(cat /tmp/smoke_body 2>/dev/null || echo "")

  if [[ "$http_status" == "$expected_status" ]]; then
    if [[ -n "$expected_body" && ! "$body" == *"$expected_body"* ]]; then
      fail "$name — status=$http_status but body missing '${expected_body}'"
    else
      pass "$name (HTTP ${http_status})"
    fi
  else
    fail "$name — expected HTTP ${expected_status} got ${http_status} (url=${url})"
  fi
}

# ─── Backend ─────────────────────────────────────────────────
log "── Backend Service ──"
check_endpoint "backend /health"        "${BASE_URL}/health"        200 "\"status\":\"ok\""
check_endpoint "backend /ready"         "${BASE_URL}/ready"         200 "\"ready\":true"
check_endpoint "backend /version"       "${BASE_URL}/version"       200 "version"
check_endpoint "backend /api/products"  "${BASE_URL}/api/products"  200 "products"
check_endpoint "backend /metrics"       "${BASE_URL}/metrics"       200 "http_requests_total"

# ─── ML Service ──────────────────────────────────────────────
ML_URL="${ML_URL:-http://ml-service.${NAMESPACE}.svc.cluster.local:5000}"
log "── ML Service ──"
check_endpoint "ml-service /health"            "${ML_URL}/health"                     200 "\"status\":\"ok\""
check_endpoint "ml-service /ready"             "${ML_URL}/ready"                      200 "\"ready\":true"
check_endpoint "ml-service /api/recommendations" "${ML_URL}/api/recommendations?user_id=smoke" 200 "recommendations"
check_endpoint "ml-service /api/demand-forecast" "${ML_URL}/api/demand-forecast?product_id=1" 200 "forecast"

# ─── Frontend ────────────────────────────────────────────────
FRONTEND_URL="${FRONTEND_URL:-${BASE_URL}}"
log "── Frontend ──"
check_endpoint "frontend /"         "${FRONTEND_URL}/"         200 ""
check_endpoint "frontend /nginx-health" "${FRONTEND_URL}/nginx-health" 200 "ok"

# ─── Summary ─────────────────────────────────────────────────
echo ""
log "══════════════════════════════"
log "Results: ${PASSED} passed, ${FAILED} failed"

if [[ "$FAILED" -gt 0 ]]; then
  log "❌ SMOKE TEST FAILED"
  exit 1
else
  log "✅ ALL SMOKE TESTS PASSED"
  exit 0
fi
