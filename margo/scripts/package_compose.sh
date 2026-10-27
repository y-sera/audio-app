#!/usr/bin/env bash
# Builds the Margo Compose Archive and pushes it to ${COMPOSE_REPO}:${VERSION}.
#   PUSH=false ./package_compose.sh  archive only
#
# Do not use `docker compose publish`: its artifact layout is not a Margo
# Compose Archive (see specification/applications/application-registry.md).
set -euo pipefail
source "$(dirname "$0")/env.sh"
require tar
check_versions

name=audio-app-compose
archive="${name}-${VERSION}-compose.tar.gz"
mkdir -p "${DIST_DIR}"

# One top-level directory containing compose.yaml. COPYFILE_DISABLE keeps
# macOS from adding AppleDouble (._*) entries.
COPYFILE_DISABLE=1 tar -czf "${DIST_DIR}/${archive}" \
  -C "${MARGO_DIR}/compose" "${name}"
tar -tzf "${DIST_DIR}/${archive}"

if [ "${PUSH:-true}" = "true" ]; then
  require oras
  cd "${DIST_DIR}"
  oras push "${COMPOSE_REPO}:${VERSION}" \
    --artifact-type application/vnd.org.margo.component.compose+json \
    "${archive}:application/vnd.org.margo.component.compose.tar+gzip" \
    --annotation "org.margo.component.type=compose" \
    --annotation "org.margo.component.version=${VERSION}" \
    --annotation "org.opencontainers.image.title=${name}" \
    --annotation "org.opencontainers.image.version=${VERSION}" \
    --annotation "org.opencontainers.image.authors=y-sera" \
    --annotation "org.opencontainers.image.description=audio-app with a LiteRT-LM server (Compose)" \
    --annotation "org.opencontainers.image.source=${SOURCE_URL}"
fi
