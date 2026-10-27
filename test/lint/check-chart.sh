#!/usr/bin/env bash
# Lints the chart and renders it with the value combinations Margo devices
# may use, checking the Margo Helm constraints on every render.
#   check-chart.sh <chart-dir>
set -euo pipefail

chart="$1"
out="$(mktemp -d)"
trap 'rm -rf "${out}"' EXIT

helm lint "${chart}"

render() {
  local name="$1"
  shift
  helm template ci "${chart}" "$@" > "${out}/${name}.yaml"
  # The WFM chooses the namespace; hooks and CRDs are not allowed.
  if grep -nE '^\s+namespace:|helm\.sh/hook|^kind: CustomResourceDefinition' "${out}/${name}.yaml"; then
    echo "error: ${name}: rendered manifest violates Margo Helm constraints" >&2
    exit 1
  fi
  echo "ok: ${name}"
}

render default
render gpu --set llm.model.backend=gpu --set-string 'llm.gpu.resources.nvidia\.com/gpu=1'
render host-audio --set app.audioDevice.mode=hostPath
render llm-only --set app.enabled=false
render external-llm --set llm.enabled=false \
  --set app.openai.baseUrl=http://llm:8080/v1 --set app.openai.model=model
render no-ui --set ui.enabled=false
render ui-cluster-ip --set ui.service.type=ClusterIP
render persistence --set app.recordings.persistence.enabled=true \
  --set llm.persistence.existingClaim=models

# GPU settings must only be rendered for the gpu backend.
if grep -n 'runtimeClassName' "${out}/default.yaml"; then
  echo "error: default (cpu) render contains a runtimeClassName" >&2
  exit 1
fi
grep -q 'runtimeClassName: nvidia' "${out}/gpu.yaml"

# The UI and the transcript API are rendered only together, and only with
# the app.
grep -q 'name: ci-audio-app-ui$' "${out}/default.yaml"
grep -q 'nodePort: 30080' "${out}/default.yaml"
grep -A1 'TRANSCRIPT_API_ENABLED' "${out}/default.yaml" | grep -q '"true"'
grep -A1 'TRANSCRIPT_API_ENABLED' "${out}/no-ui.yaml" | grep -q '"false"'
for name in no-ui llm-only; do
  if grep -nE 'name: ci-audio-app-(ui|api)$' "${out}/${name}.yaml"; then
    echo "error: ${name} render contains UI objects" >&2
    exit 1
  fi
done
if grep -n 'nodePort' "${out}/ui-cluster-ip.yaml"; then
  echo "error: ClusterIP UI service has a nodePort" >&2
  exit 1
fi
echo "ok: UI toggling"

# Invalid values must fail.
if helm template ci "${chart}" --set llm.model.backend=npu > /dev/null 2>&1; then
  echo "error: backend npu was accepted" >&2
  exit 1
fi
echo "ok: invalid values rejected"
