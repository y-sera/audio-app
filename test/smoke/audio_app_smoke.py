"""Smoke test run inside the built audio-app image (no microphone needed).

Exercises the runtime dependencies the app relies on: PortAudio bindings,
numpy, onnxruntime (Silero VAD on a real utterance and on silence), the
WAV helpers, the OpenAI client and the transcript API read by the UI.

    docker run --rm -v "$PWD/test:/test:ro" --entrypoint /app/.venv/bin/python \
      <image> /test/smoke/audio_app_smoke.py /test/e2e/fixtures/sample.wav
"""

import io
import json
import os
import sys
import urllib.request
import wave

# transcription.py reads these at import time.
os.environ.setdefault("OPENAI_API_KEY", "dummy")
os.environ.setdefault("OPENAI_BASE_URL", "http://127.0.0.1:9/v1")
os.environ.setdefault("OPENAI_MODEL", "smoke-test")
# Any free port for the transcript API.
os.environ.setdefault("TRANSCRIPT_API_HOST", "127.0.0.1")
os.environ.setdefault("TRANSCRIPT_API_PORT", "0")

import numpy as np  # noqa: E402
import pyaudio  # noqa: E402

from app import transcription  # noqa: E402
from app.audio import pcm_to_wav_bytes, prepare_vad_block  # noqa: E402
from app.config import AUDIO_INPUT_RATE, VAD_CHUNK, VAD_MODEL_PATH  # noqa: E402
from app.transcript_server import start_transcript_server, transcripts  # noqa: E402
from app.vad import SileroVAD  # noqa: E402


def max_speech_probability(vad: SileroVAD, pcm: np.ndarray) -> float:
    vad.reset()
    best = 0.0
    for start in range(0, len(pcm) - VAD_CHUNK + 1, VAD_CHUNK):
        block = prepare_vad_block(pcm[start : start + VAD_CHUNK])
        best = max(best, float(vad(block)))
    return best


def main() -> int:
    wav_path = sys.argv[1]

    print(f"PortAudio: {pyaudio.get_portaudio_version_text()}")

    with wave.open(wav_path, "rb") as w:
        assert w.getframerate() == AUDIO_INPUT_RATE, w.getframerate()
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        speech = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)

    # WAV round trip through the app's helper.
    with wave.open(io.BytesIO(pcm_to_wav_bytes(speech.tobytes(), AUDIO_INPUT_RATE, 1, 2))) as w:
        assert np.array_equal(np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16), speech)
    print("WAV round trip: ok")

    vad = SileroVAD(VAD_MODEL_PATH)
    speech_prob = max_speech_probability(vad, speech)
    silence_prob = max_speech_probability(vad, np.zeros(AUDIO_INPUT_RATE, dtype=np.int16))
    print(f"VAD max speech probability: speech={speech_prob:.3f} silence={silence_prob:.3f}")
    assert speech_prob > 0.5, "VAD did not detect speech in the fixture"
    assert silence_prob < 0.5, "VAD detected speech in silence"

    client = transcription.client
    assert str(client.base_url).startswith(os.environ["OPENAI_BASE_URL"])
    assert callable(client.chat.completions.create)
    print("OpenAI client: ok")

    server = start_transcript_server()
    base = f"http://127.0.0.1:{server.server_address[1]}"
    transcripts.add("smoke test", 1)
    with urllib.request.urlopen(f"{base}/api/transcripts", timeout=5) as r:
        items = json.load(r)["transcripts"]
    assert [t["text"] for t in items] == ["smoke test"], items
    with urllib.request.urlopen(f"{base}/api/events", timeout=5) as r:
        assert r.headers["Content-Type"] == "text/event-stream"
        assert r.readline() == b"event: snapshot\n"
        assert b"smoke test" in r.readline()
    server.shutdown()
    print("Transcript API: ok")

    print("Smoke test passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
