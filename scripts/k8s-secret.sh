#!/usr/bin/env bash
set -euo pipefail
# Secret bytes are created in RAM/on a protected temporary file, never echoed or committed.
namespace=${K8S_NAMESPACE:-devops-assessment}
kubectl get namespace "$namespace" >/dev/null 2>&1 || kubectl create namespace "$namespace"
umask 077
secret_file=$(mktemp)
trap 'rm -f "$secret_file"' EXIT
openssl rand -hex 32 > "$secret_file"
# Strip the newline so the bearer-token value is exact.
tr -d '\n' < "$secret_file" > "${secret_file}.clean"
trap 'rm -f "$secret_file" "${secret_file}.clean"' EXIT
kubectl -n "$namespace" create secret generic app-secrets \
  --from-file="metrics-token=${secret_file}.clean" --dry-run=client -o yaml | kubectl apply -f -
