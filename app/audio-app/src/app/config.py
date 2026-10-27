import os

import pyaudio


# ============================================================
# Configuration
# ============================================================

# Single fixed sample rate (Hz) for the whole pipeline: the microphone is
# captured directly at this rate and the Silero VAD ONNX model consumes
# windows at it (512-sample chunks at 16 kHz), so no resampler is needed.
AUDIO_INPUT_RATE = 16000

CHANNELS = 1
FORMAT = pyaudio.paInt16

# 32 ms blocks: AUDIO_INPUT_RATE * CHUNK_MS / 1000 = 512 samples, exactly
# the window the VAD model expects.
CHUNK_MS = 32
INPUT_CHUNK = int(AUDIO_INPUT_RATE * CHUNK_MS / 1000)

VAD_CHUNK = 512

VAD_THRESHOLD = float(os.getenv("VAD_THRESHOLD", "0.3"))

# Exit threshold for two-threshold hysteresis. While a recording is
# active the lower VAD_THRESHOLD_END is used so short dips in the
# speech probability do not stop the recording.
VAD_THRESHOLD_END = float(os.getenv("VAD_THRESHOLD_END", "0.2"))

# Linear gain applied ONLY to the float signal handed to the VAD model.
# Does not affect the PCM saved to the WAV file. Only used when the
# automatic VAD normalisation is disabled (VAD_AUTO_NORM=0).
VAD_GAIN = float(os.getenv("VAD_GAIN", "1.0"))

# Saturation guard: fraction of a chunk pinned at the int16 rails above
# which the capture is treated as clipping, so the gain is not applied.
VAD_CLIP_LIMIT = float(os.getenv("VAD_CLIP_LIMIT", "0.02"))

# Optional level conditioning applied to the signal handed to the VAD
# model only (the saved WAV is always the original PCM). Off by default
# so the captured block is passed through unchanged; enable it
# (VAD_AUTO_NORM=1) to strip DC and peak-normalise very quiet or very
# hot captures. The deployment enables this by default.
VAD_AUTO_NORM = os.getenv("VAD_AUTO_NORM", "0") == "1"
VAD_TARGET_PEAK = float(os.getenv("VAD_TARGET_PEAK", "0.6"))
VAD_MAX_NORM_GAIN = float(os.getenv("VAD_MAX_NORM_GAIN", "16.0"))

MIN_SPEECH_MS = int(os.getenv("MIN_SPEECH_MS", "150"))
MIN_SILENCE_MS = int(os.getenv("MIN_SILENCE_MS", "700"))

PRE_ROLL_MS = 300

MAX_UTTERANCE_MS = 10000

OUTPUT_DIR = os.getenv(
    "OUTPUT_DIR",
    "./recordings",
)

VAD_MODEL_PATH = os.getenv(
    "VAD_MODEL_PATH",
    "/app/models/silero_vad.onnx",
)

# Read-only HTTP API (JSON + Server-Sent Events) that the UI reads the
# transcripts from. Off by default; the deployments enable it together
# with the UI.
TRANSCRIPT_API_ENABLED = os.getenv(
    "TRANSCRIPT_API_ENABLED",
    "false",
).lower() in ("1", "true", "yes")
TRANSCRIPT_API_HOST = os.getenv("TRANSCRIPT_API_HOST", "0.0.0.0")
TRANSCRIPT_API_PORT = int(os.getenv("TRANSCRIPT_API_PORT", "8000"))

# Number of recent transcripts kept in memory for the UI.
TRANSCRIPT_HISTORY = int(os.getenv("TRANSCRIPT_HISTORY", "200"))
