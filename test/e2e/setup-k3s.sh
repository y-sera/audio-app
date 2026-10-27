#!/usr/bin/env bash
# Installs a pinned k3s release, verifies its checksum and starts a
# single-node server. Exports KUBECONFIG to later steps on GitHub Actions.
set -euo pipefail

K3S_VERSION="v1.37.1+k3s1"
# From sha256sum-<arch>.txt of the release above. Update both together.
declare -A K3S_SHA256=(
  [amd64]=92b94582eb7b34a8cf532e6006842b9ed215a6783cf56a3dd6271fd35243b2c0
  [arm64]=a1561ca4aef8b99f5588a840d4468ac39c8c1cd92470bbcb9634823fa221741a
)

case "$(uname -m)" in
  x86_64) arch=amd64; asset=k3s ;;
  aarch64 | arm64) arch=arm64; asset=k3s-arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
curl -fsSL --retry 3 -o "${tmp}/k3s" \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION//+/%2B}/${asset}"
echo "${K3S_SHA256[${arch}]}  ${tmp}/k3s" | sha256sum -c -
sudo install -m 0755 "${tmp}/k3s" /usr/local/bin/k3s
sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

# Ingress, load balancer and metrics are not needed for the test.
sudo mkdir -p /var/log/k3s
sudo sh -c 'nohup /usr/local/bin/k3s server \
  --write-kubeconfig-mode=0644 \
  --disable=traefik,servicelb,metrics-server \
  > /var/log/k3s/server.log 2>&1 &'

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "KUBECONFIG=${KUBECONFIG}" >> "${GITHUB_ENV}"
fi

# The API server answers before the node has registered, so wait until a
# node object exists before waiting for it to become Ready.
for _ in $(seq 1 90); do
  if [ -f "${KUBECONFIG}" ] && [ -n "$(kubectl get nodes -o name 2>/dev/null)" ]; then
    break
  fi
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl get nodes -o wide
