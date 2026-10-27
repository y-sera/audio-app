#!/bin/sh
# With UI_ENABLED=false the container stays up without serving anything.
# Compose cannot drop a service based on a variable, and an exited
# container would make the deployment look partially failed.
set -eu

case "$(echo "${UI_ENABLED:-true}" | tr '[:upper:]' '[:lower:]')" in
  1 | true | yes) ;;
  *)
    echo "UI disabled (UI_ENABLED=${UI_ENABLED}); not serving."
    exec sleep infinity
    ;;
esac

exec /docker-entrypoint.sh nginx -g "daemon off;"
