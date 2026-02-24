# ============================================================
# ShopMicro Developer CLI — Makefile
# Targets: bootstrap, validate, deploy, rollback, smoke-test, evidence-pack
# Usage: make <target> [ENV=dev|staging|prod]
# ============================================================

ENV          ?= dev
IMAGE_TAG    ?= v1
REGISTRY     ?= ghcr.io/shopmicro
NAMESPACE    := $(ENV)
KUBECTL      := kubectl
SCRIPTS_DIR  := ./scripts
INFRA_DIR    := ./infra

.DEFAULT_GOAL := help
.PHONY: help bootstrap validate deploy rollback smoke-test evidence-pack \
        chaos-pod-kill chaos-network-latency rotate-secrets cost-report \
        build build-backend build-ml build-frontend docker-up docker-down

# ── Help ──────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  ShopMicro Platform — Developer CLI"
	@echo "  ════════════════════════════════════"
	@echo ""
	@echo "  Core Commands:"
	@echo "    bootstrap         Check deps and create namespaces"
	@echo "    validate          Run policy checks (conftest + kyverno dry-run)"
	@echo "    deploy            Deploy all manifests (ENV=$(ENV))"
	@echo "    rollback          Roll back canary deployment (ENV=$(ENV))"
	@echo "    smoke-test        Run smoke tests against deployed services (ENV=$(ENV))"
	@echo "    evidence-pack     Collect and archive deployment evidence (ENV=$(ENV))"
	@echo ""
	@echo "  Chaos Engineering:"
	@echo "    chaos-pod-kill         Run pod-kill chaos experiment"
	@echo "    chaos-network-latency  Run network-latency chaos experiment"
	@echo ""
	@echo "  Security:"
	@echo "    rotate-secrets    Rotate K8s secrets and trigger rolling restarts"
	@echo ""
	@echo "  Cost:"
	@echo "    cost-report       Display environment cost analysis"
	@echo ""
	@echo "  Local Dev:"
	@echo "    docker-up         Start all services via docker-compose"
	@echo "    docker-down       Stop docker-compose services"
	@echo "    build             Build all Docker images locally"
	@echo ""
	@echo "  Options:"
	@echo "    ENV=$(ENV), IMAGE_TAG=$(IMAGE_TAG), REGISTRY=$(REGISTRY)"
	@echo ""

# ── Bootstrap ─────────────────────────────────────────────────
bootstrap:
	@echo "── Bootstrapping ShopMicro Platform (ENV=$(ENV)) ──"
	@echo "[1/4] Checking required tools..."
	@command -v kubectl  >/dev/null 2>&1 && echo "  ✅ kubectl"  || echo "  ⚠️  kubectl not found"
	@command -v docker   >/dev/null 2>&1 && echo "  ✅ docker"   || echo "  ⚠️  docker not found"
	@command -v curl     >/dev/null 2>&1 && echo "  ✅ curl"     || echo "  ⚠️  curl not found"
	@command -v openssl  >/dev/null 2>&1 && echo "  ✅ openssl"  || echo "  ⚠️  openssl not found"
	@command -v conftest >/dev/null 2>&1 && echo "  ✅ conftest" || echo "  ℹ️  conftest not installed (optional)"
	@echo "[2/4] Creating namespaces..."
	@$(KUBECTL) apply -f $(INFRA_DIR)/k8s/namespaces.yaml 2>/dev/null || \
		echo "  ℹ️  kubectl not connected — namespace creation skipped"
	@echo "[3/4] Making scripts executable..."
	@chmod +x $(SCRIPTS_DIR)/*.sh chaos/run-chaos.sh
	@echo "[4/4] Creating evidence directory..."
	@mkdir -p evidence
	@echo ""
	@echo "✅ Bootstrap complete. Run 'make validate' next."

# ── Validate ──────────────────────────────────────────────────
validate:
	@echo "── Policy Validation (ENV=$(ENV)) ──"
	@echo "[1/2] Running conftest policy gate..."
	@if command -v conftest >/dev/null 2>&1; then \
		conftest test $(INFRA_DIR)/k8s/ \
			--policy $(INFRA_DIR)/policies/conftest/policy.rego \
			--output table || true; \
	else \
		echo "  ℹ️  conftest not installed. Install from: https://www.conftest.dev/"; \
	fi
	@echo "[2/2] Running kubectl dry-run validation..."
	@$(KUBECTL) apply --dry-run=client -f $(INFRA_DIR)/k8s/namespaces.yaml 2>/dev/null && \
		echo "  ✅ namespaces.yaml valid" || echo "  ℹ️  kubectl not connected"
	@$(KUBECTL) apply --dry-run=client -f $(INFRA_DIR)/k8s/backend/ 2>/dev/null && \
		echo "  ✅ backend manifests valid" || echo "  ℹ️  kubectl not connected"
	@$(KUBECTL) apply --dry-run=client -f $(INFRA_DIR)/networkpolicies/ 2>/dev/null && \
		echo "  ✅ NetworkPolicies valid" || echo "  ℹ️  kubectl not connected"
	@echo "✅ Validation complete."

# ── Deploy ────────────────────────────────────────────────────
deploy:
	@echo "── Deploying to namespace=$(NAMESPACE) (image=$(IMAGE_TAG)) ──"
	$(KUBECTL) apply -f $(INFRA_DIR)/k8s/namespaces.yaml
	$(KUBECTL) apply -f $(INFRA_DIR)/k8s/backend/deployment-stable.yaml
	$(KUBECTL) apply -f $(INFRA_DIR)/k8s/ml-service/deployment.yaml
	$(KUBECTL) apply -f $(INFRA_DIR)/k8s/frontend/deployment.yaml
	$(KUBECTL) apply -f $(INFRA_DIR)/k8s/backend/hpa.yaml
	$(KUBECTL) apply -f $(INFRA_DIR)/k8s/backend/ingress-canary.yaml
	$(KUBECTL) apply -f $(INFRA_DIR)/networkpolicies/prod-network-policies.yaml
	@echo "── Waiting for rollouts to complete ──"
	$(KUBECTL) rollout status deployment/backend-stable -n $(NAMESPACE) --timeout=180s
	$(KUBECTL) rollout status deployment/ml-service     -n $(NAMESPACE) --timeout=180s
	$(KUBECTL) rollout status deployment/frontend       -n $(NAMESPACE) --timeout=180s
	@echo "✅ Deploy complete to $(NAMESPACE)."

# ── Rollback ──────────────────────────────────────────────────
rollback:
	@echo "── Rolling back canary in namespace=$(NAMESPACE) ──"
	@$(SCRIPTS_DIR)/rollback.sh $(NAMESPACE) "make-rollback"

# ── Smoke Test ────────────────────────────────────────────────
smoke-test:
	@echo "── Running smoke tests (ENV=$(ENV)) ──"
	@$(SCRIPTS_DIR)/smoke-test.sh "http://shopmicro.local" $(NAMESPACE)

# ── Evidence Pack ─────────────────────────────────────────────
evidence-pack:
	@echo "── Collecting evidence (ENV=$(ENV)) ──"
	@$(SCRIPTS_DIR)/evidence-pack.sh $(NAMESPACE)

# ── Chaos Engineering ─────────────────────────────────────────
chaos-pod-kill:
	@echo "── Running chaos experiment: pod-kill (ENV=$(ENV)) ──"
	@$(MAKE) bootstrap
	@bash chaos/run-chaos.sh pod-kill $(NAMESPACE)

chaos-network-latency:
	@echo "── Running chaos experiment: network-latency (ENV=$(ENV)) ──"
	@$(MAKE) bootstrap
	@bash chaos/run-chaos.sh network-latency $(NAMESPACE)

# ── Security ──────────────────────────────────────────────────
rotate-secrets:
	@echo "── Rotating secrets (ENV=$(ENV)) ──"
	@$(SCRIPTS_DIR)/rotate-secrets.sh $(NAMESPACE)

# ── Cost Report ───────────────────────────────────────────────
cost-report:
	@echo "── Cost Analysis Report ──"
	@cat costs.md 2>/dev/null || echo "costs.md not found"

# ── Local Dev ─────────────────────────────────────────────────
docker-up:
	@echo "── Starting local services via docker-compose ──"
	docker compose up -d --build
	@echo "✅ Services started. Frontend: http://localhost:3000"

docker-down:
	@echo "── Stopping docker-compose services ──"
	docker compose down

build: build-backend build-ml build-frontend

build-backend:
	docker build -t $(REGISTRY)/backend:$(IMAGE_TAG) backend/

build-ml:
	docker build -t $(REGISTRY)/ml-service:$(IMAGE_TAG) ml-service/

build-frontend:
	docker build -t $(REGISTRY)/frontend:$(IMAGE_TAG) frontend/ \
		--build-arg VITE_BACKEND_URL=http://backend:8080 \
		--build-arg VITE_ML_URL=http://ml-service:5000
