#!/usr/bin/env bash
set -euo pipefail
# Sampling runs INSIDE the cluster so it keeps following Service endpoints during pod replacement.
namespace=${K8S_NAMESPACE:-devops-assessment}
new_image=${1:?Usage: k8s-rollout.sh image:version}
log_dir=${EVIDENCE_DIR:-docs/evidence}
mkdir -p "$log_dir"
probe="availability-$RANDOM"
# These dollar expressions are evaluated by the probe container's shell.
# shellcheck disable=SC2016
kubectl -n "$namespace" run "$probe" --image=curlimages/curl:8.16.0 --restart=Never \
  --overrides='{"spec":{"automountServiceAccountToken":false,"securityContext":{"runAsNonRoot":true,"runAsUser":100,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"availability","image":"curlimages/curl:8.16.0","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"command":["sh","-c","i=0; while [ $i -lt 180 ]; do code=$(curl -s -o /dev/null -w %{http_code} --max-time 2 http://app/health) || code=000; echo $code; i=$((i+1)); sleep 1; done"]}]}}'
trap 'kubectl -n "$namespace" delete pod "$probe" --ignore-not-found >/dev/null' EXIT
kubectl -n "$namespace" wait --for=condition=Ready "pod/$probe" --timeout=90s
{
  kubectl -n "$namespace" set image deployment/app "app=$new_image"
  kubectl -n "$namespace" rollout status deployment/app --timeout=180s
  kubectl -n "$namespace" rollout undo deployment/app
  kubectl -n "$namespace" rollout status deployment/app --timeout=180s
  kubectl -n "$namespace" get pods -o wide
} | tee "$log_dir/kubernetes-rollout.txt"
kubectl -n "$namespace" logs "$probe" > "$log_dir/kubernetes-availability.txt"
awk 'BEGIN {n=0} {n++; if($0!="200") bad++} END {print "samples=" n, "failed=" bad+0; exit(n<2 || bad>0)}' "$log_dir/kubernetes-availability.txt"
