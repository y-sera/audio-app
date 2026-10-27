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
render persistence --set app.recordings.persistence.enabled=true \
  --set llm.persistence.existingClaim=models

# GPU settings must only be rendered for the gpu backend.
if grep -n 'runtimeClassName' "${out}/default.yaml"; then
  echo "error: default (cpu) render contains a runtimeClassName" >&2
  exit 1
fi
grep -q 'runtimeClassName: nvidia' "${out}/gpu.yaml"

# Invalid values must fail.
if helm template ci "${chart}" --set llm.model.backend=npu > /dev/null 2>&1; then
  echo "error: backend npu was accepted" >&2
  exit 1
fi
echo "ok: invalid values rejected"
