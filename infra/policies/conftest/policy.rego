# Conftest/OPA policies for Kubernetes manifest validation
# Run: conftest test infra/k8s/ --policy infra/policies/conftest/

package main

# Deny pods without resource limits
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("Container '%s' must define CPU limits", [container.name])
}

deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Container '%s' must define memory limits", [container.name])
}

# Deny latest image tag
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' uses ':latest' tag — pin to a specific version", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  msg := sprintf("Container '%s' has no image tag — pin to a specific version", [container.name])
}

# Deny missing liveness probe
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.livenessProbe
  msg := sprintf("Container '%s' must define a livenessProbe", [container.name])
}

# Deny missing readiness probe
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.readinessProbe
  msg := sprintf("Container '%s' must define a readinessProbe", [container.name])
}

# Deny privileged containers
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' must not run as privileged", [container.name])
}

# Warn on missing app label
warn[msg] {
  input.kind == "Deployment"
  not input.metadata.labels.app
  msg := "Deployment should have an 'app' label"
}
