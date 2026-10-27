import json
import threading
from collections import deque
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .config import (
    TRANSCRIPT_API_HOST,
    TRANSCRIPT_API_PORT,
    TRANSCRIPT_HISTORY,
)
from .logging_config import logger


# ============================================================
# Transcript store
# ============================================================

class TranscriptStore:
    """Keeps the most recent transcripts and wakes up waiting readers."""

    def __init__(self, max_items: int) -> None:
        self._items: deque[dict] = deque(maxlen=max_items)
        self._last_id = 0
        self._cond = threading.Condition()

    def add(self, text: str, utterance_id: int) -> dict:
        with self._cond:
            self._last_id += 1

            item = {
                "id": self._last_id,
                "utterance": utterance_id,
                "text": text,
                "timestamp": datetime.now(timezone.utc).isoformat(
                    timespec="milliseconds"
                ),
            }

            self._items.append(item)
            self._cond.notify_all()

        return item

    def snapshot(self) -> tuple[int, list[dict]]:
        with self._cond:
            return self._last_id, list(self._items)

    def wait_newer(
        self,
        last_id: int,
        timeout: float,
    ) -> list[dict]:
        """Returns the items newer than last_id, waiting up to timeout."""

        with self._cond:
            self._cond.wait_for(
                lambda: self._last_id > last_id,
                timeout,
            )

            return [
                item for item in self._items
                if item["id"] > last_id
            ]


transcripts = TranscriptStore(TRANSCRIPT_HISTORY)


# ============================================================
# HTTP API
# ============================================================

# Interval of SSE keep-alive comments, so idle connections are not closed
# by proxies.
KEEPALIVE_SECONDS = 15.0


class TranscriptHandler(BaseHTTPRequestHandler):
    """Read-only API used by the UI.

    GET /api/transcripts  recent transcripts as JSON
    GET /api/events       Server-Sent Events: a "snapshot" event with the
                          recent transcripts, then a "transcript" event
                          for each new one
    GET /healthz          liveness
    """

    server_version = "audio-app"
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]

        if path == "/healthz":
            self._send_json({"status": "ok"})

        elif path == "/api/transcripts":
            _, items = transcripts.snapshot()
            self._send_json({"transcripts": items})

        elif path == "/api/events":
            self._stream_events()

        else:
            self._send_json({"error": "not found"}, status=404)

    def _send_json(
        self,
        body: dict,
        status: int = 200,
    ) -> None:
        data = json.dumps(body).encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _send_event(
        self,
        event: str,
        body: dict,
    ) -> None:
        data = json.dumps(body)

        self.wfile.write(
            f"event: {event}\ndata: {data}\n\n".encode("utf-8")
        )
        self.wfile.flush()

    def _stream_events(self) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-store")
        # Disables response buffering in nginx.
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()

        # The stream has no length, so the connection ends with it.
        self.close_connection = True

        last_id, items = transcripts.snapshot()

        try:
            self._send_event(
                "snapshot",
                {"transcripts": items},
            )

            while True:
                newer = transcripts.wait_newer(
                    last_id,
                    KEEPALIVE_SECONDS,
                )

                if not newer:
                    self.wfile.write(b": keep-alive\n\n")
                    self.wfile.flush()
                    continue

                for item in newer:
                    self._send_event("transcript", item)

                last_id = newer[-1]["id"]

        except (BrokenPipeError, ConnectionResetError):
            logger.debug("SSE client disconnected")

    def log_message(self, format: str, *args) -> None:
        logger.debug(
            "API %s - %s",
            self.address_string(),
            format % args,
        )


def start_transcript_server() -> ThreadingHTTPServer:
    server = ThreadingHTTPServer(
        (TRANSCRIPT_API_HOST, TRANSCRIPT_API_PORT),
        TranscriptHandler,
    )
    server.daemon_threads = True

    thread = threading.Thread(
        target=server.serve_forever,
        name="transcript-api",
        daemon=True,
    )
    thread.start()

    logger.info(
        "Transcript API listening on %s:%d",
        TRANSCRIPT_API_HOST,
        server.server_address[1],
    )

    return server
