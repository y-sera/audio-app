#!/usr/bin/env bash
# Packages the Helm chart and pushes it to oci://${CHART_REPO}/audio-app:${VERSION}.
#   PUSH=false ./package_helm.sh  package only
set -euo pipefail
source "$(dirname "$0")/env.sh"
require helm
check_versions

mkdir -p "${DIST_DIR}"
helm lint "${MARGO_DIR}/helm/audio-app"
helm package "${MARGO_DIR}/helm/audio-app" --destination "${DIST_DIR}"

if [ "${PUSH:-true}" = "true" ]; then
  helm push "${DIST_DIR}/audio-app-${VERSION}.tgz" "oci://${CHART_REPO}"
fi
