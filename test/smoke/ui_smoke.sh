#!/usr/bin/env bash
# Runs the UI image against the transcript API of the audio-app image (no
# microphone needed) and checks the page, the API proxy, the SSE stream and
# the disabled mode.
#   ui_smoke.sh <audio-app-image> <ui-image>
set -euo pipefail

app_image="$1"
ui_image="$2"
name="ui-smoke-$$"
port=18090

cleanup() {
  docker rm -f "${name}-api" "${name}-ui" "${name}-off" > /dev/null 2>&1 || true
  docker network rm "${name}" > /dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "${name}" > /dev/null

# Transcript API only, fed with one transcript now and one a few seconds later.
docker run -d --name "${name}-api" --network "${name}" --network-alias audio-app \
  --entrypoint /app/.venv/bin/python "${app_image}" -c '
import time
from app.transcript_server import start_transcript_server, transcripts
start_transcript_server()
transcripts.add("first transcript", 1)
time.sleep(5)
transcripts.add("second transcript", 2)
while True:
    time.sleep(60)
' > /dev/null

docker run -d --name "${name}-ui" --network "${name}" \
  -p "127.0.0.1:${port}:8080" "${ui_image}" > /dev/null

for _ in $(seq 30); do
  curl -fsS "http://127.0.0.1:${port}/healthz" > /dev/null 2>&1 && break
  sleep 1
done

curl -fsS "http://127.0.0.1:${port}/" | grep -q '<div id="root">'
echo "page: ok"

# Client-side routes fall back to the page.
curl -fsS "http://127.0.0.1:${port}/any/route" | grep -q '<div id="root">'

curl -fsS "http://127.0.0.1:${port}/api/transcripts" | grep -q 'first transcript'
echo "API proxy: ok"

# Ends with a timeout, since the stream does not end by itself.
events="$(curl -sN --max-time 10 "http://127.0.0.1:${port}/api/events" || true)"
grep -q '^event: snapshot' <<< "${events}"
grep -q '^event: transcript' <<< "${events}"
grep -q 'second transcript' <<< "${events}"
echo "SSE stream: ok"

# Disabled: the container keeps running but serves nothing.
docker run -d --name "${name}-off" -e UI_ENABLED=false -p "127.0.0.1:$((port + 1)):8080" \
  "${ui_image}" > /dev/null
sleep 3
[ "$(docker inspect -f '{{.State.Running}}' "${name}-off")" = "true" ]
if curl -fsS --max-time 3 "http://127.0.0.1:$((port + 1))/" > /dev/null 2>&1; then
  echo "error: disabled UI is serving" >&2
  exit 1
fi
echo "disabled mode: ok"

echo "UI smoke test passed"
