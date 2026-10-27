# Shared settings for the packaging scripts. Source, don't execute.
#
# The registry is provisional. When it changes, also update the references in:
#   helm/audio-app/values.yaml                          (app/llm/ui image.repository)
#   compose/audio-app-compose/compose.yaml              (services.*.image)
#   application-description/margo.yaml                  (components[].properties.repository)

MARGO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SRC_DIR="$(cd "${MARGO_DIR}/../app" && pwd)"
DIST_DIR="${MARGO_DIR}/dist"

REGISTRY="${REGISTRY:-ghcr.io/y-sera/audio-app}"
VERSION="${VERSION:-0.1.1}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

APP_IMAGE="${REGISTRY}/audio-app"
LLM_IMAGE="${REGISTRY}/litert-lm"
UI_IMAGE="${REGISTRY}/ui"
CHART_REPO="${REGISTRY}/charts"            # chart lands at ${CHART_REPO}/audio-app
COMPOSE_REPO="${REGISTRY}/compose/audio-app-compose"
APP_PACKAGE_REPO="${REGISTRY}/margo-package"
# Links pushed OCI artifacts to the repository on GHCR.
SOURCE_URL="${SOURCE_URL:-https://github.com/y-sera/audio-app}"

require() {
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null || { echo "error: ${cmd} is required" >&2; exit 1; }
  done
}

# Fails when the versions in the chart, compose file and application
# description drift from ${VERSION}.
check_versions() {
  require yq
  local chart_version app_version description_version
  chart_version="$(yq '.version' "${MARGO_DIR}/helm/audio-app/Chart.yaml")"
  app_version="$(yq '.appVersion' "${MARGO_DIR}/helm/audio-app/Chart.yaml")"
  description_version="$(yq '.metadata.version' "${MARGO_DIR}/application-description/margo.yaml")"
  for v in "${chart_version}" "${app_version}" "${description_version}"; do
    [ "${v}" = "${VERSION}" ] || { echo "error: version ${v} != VERSION ${VERSION}" >&2; exit 1; }
  done
  yq '.deploymentProfiles[].components[].properties.revision' \
    "${MARGO_DIR}/application-description/margo.yaml" | while read -r rev; do
    [ "${rev}" = "${VERSION}" ] || { echo "error: component revision ${rev} != VERSION ${VERSION}" >&2; exit 1; }
  done
  grep -q ":${VERSION}\$" <(yq '.services[].image' "${MARGO_DIR}/compose/audio-app-compose/compose.yaml") \
    || { echo "error: compose images are not tagged ${VERSION}" >&2; exit 1; }
}
