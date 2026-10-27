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
  # --load can only import a single platform into the local image store.
  if [[ "${PLATFORMS}" == *,* ]]; then
    echo "error: set PLATFORMS to one platform (e.g. linux/amd64) with PUSH=false" >&2
    exit 1
  fi
  output=(--load)
fi

docker buildx build --platform "${PLATFORMS}" "${output[@]}" \
  -t "${APP_IMAGE}:${VERSION}" \
  "${APP_SRC_DIR}/audio-app"

docker buildx build --platform "${PLATFORMS}" "${output[@]}" \
  -t "${LLM_IMAGE}:${VERSION}" \
  "${APP_SRC_DIR}/litert-lm"
