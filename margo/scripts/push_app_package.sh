#!/usr/bin/env bash
# Pushes the Margo Application Package (application description + resources)
# to ${APP_PACKAGE_REPO}:${VERSION}. The tag MUST equal metadata.version.
set -euo pipefail
source "$(dirname "$0")/env.sh"
require oras
check_versions

annotations="$(mktemp)"
trap 'rm -f "${annotations}"' EXIT
cat > "${annotations}" <<'EOF'
{
  "resources/description.md": { "org.margo.app.resource": "descriptionFile" },
  "resources/release-notes.md": { "org.margo.app.resource": "releaseNotes" },
  "resources/license.md": { "org.margo.app.resource": "licenseFile" },
  "resources/icon.png": { "org.margo.app.resource": "icon" }
}
EOF

# Paths are relative so the layer titles match the references in margo.yaml.
cd "${MARGO_DIR}/application-description"
oras push "${APP_PACKAGE_REPO}:${VERSION}" \
  --artifact-type application/vnd.margo.app.v1+json \
  --annotation-file "${annotations}" \
  margo.yaml:application/vnd.margo.app.description.v1+yaml \
  resources/description.md:application/vnd.margo.app.descriptionFile.v1+markdown \
  resources/release-notes.md:application/vnd.margo.app.releaseNotes.v1+markdown \
  resources/license.md:application/vnd.margo.app.licenseFile.v1+markdown \
  resources/icon.png:application/vnd.margo.app.icon.v1+png
