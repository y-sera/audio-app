#!/usr/bin/env bash
# Builds the container images and pushes them to ${REGISTRY}.
#   ./build_images.sh            build and push
#   PUSH=false ./build_images.sh build into the local image store only
set -euo pipefail
source "$(dirname "$0")/env.sh"
require docker

PUSH="${PUSH:-true}"
if [ "${PUSH}" = "true" ]; then
  output=(--push)
else
  output=(--load)
fi

docker buildx build --platform "${PLATFORMS}" "${output[@]}" \
  -t "${APP_IMAGE}:${VERSION}" \
  "${APP_SRC_DIR}/audio-app"

docker buildx build --platform "${PLATFORMS}" "${output[@]}" \
  -t "${LLM_IMAGE}:${VERSION}" \
  "${APP_SRC_DIR}/litert-lm"
