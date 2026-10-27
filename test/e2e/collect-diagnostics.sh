#!/usr/bin/env bash
# Dumps cluster state and logs for a failed E2E run.
#   collect-diagnostics.sh <namespace> <output-dir>
set -uo pipefail

namespace="$1"
out="$2"
mkdir -p "${out}"

kubectl get all,pvc,pv,events -A -o wide > "${out}/resources.txt" 2>&1
kubectl -n "${namespace}" describe pods > "${out}/describe-pods.txt" 2>&1
for pod in $(kubectl -n "${namespace}" get pods -o name 2>/dev/null); do
  name="${pod#pod/}"
  kubectl -n "${namespace}" logs "${pod}" --all-containers --prefix \
    > "${out}/${name}.log" 2>&1
  kubectl -n "${namespace}" logs "${pod}" --all-containers --prefix --previous \
    > "${out}/${name}.previous.log" 2>/dev/null || rm -f "${out}/${name}.previous.log"
done
sudo cp /var/log/k3s/server.log "${out}/k3s-server.log" 2>/dev/null
sudo chown -R "$(id -u):$(id -g)" "${out}"
