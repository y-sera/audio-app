"""E2E check for the LiteRT-LM server deployed by the audio-app chart.

1. Waits until the OpenAI-compatible API is up and lists the model.
2. Sends a WAV fixture the same way the audio-app does (LiteRT-LM audio
   content part) and checks that the transcription contains every keyword
   listed in the keywords file.

Uses the standard library only, so it runs on a bare CI runner.
"""

import argparse
import base64
import json
import os
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

# Keep in sync with OPENAI_PROMPT in app/audio-app/src/app/transcription.py.
DEFAULT_PROMPT = (
    "この音声を日本語で"
    "文字起こししてください。"
    "音声に含まれている発話だけを"
    "返してください。"
    "説明や補足は不要です。"
)


def log(message: str) -> None:
    print(message, flush=True)


def annotate(level: str, message: str) -> None:
    """Prints a GitHub Actions annotation (plain output elsewhere)."""
    if os.getenv("GITHUB_ACTIONS") == "true":
        log(f"::{level}::{message}")
    else:
        log(f"{level.upper()}: {message}")


def summary(markdown: str) -> None:
    path = os.getenv("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(markdown + "\n")


def request(url: str, payload: dict | None = None, timeout: float = 30) -> dict:
    data = None
    headers = {"Authorization": "Bearer dummy"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def wait_for_model(base_url: str, model: str, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    last_error = None
    while time.monotonic() < deadline:
        try:
            models = request(f"{base_url}/models")
            ids = [m.get("id") for m in models.get("data", [])]
            if model in ids:
                log(f"Model {model} is available: {ids}")
                return
            last_error = f"model not listed: {ids}"
        except (urllib.error.URLError, OSError, ValueError) as e:
            last_error = str(e)
        time.sleep(5)
    raise TimeoutError(f"{base_url}/models not ready after {timeout}s: {last_error}")


def load_keywords(path: Path) -> list[str]:
    keywords = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            keywords.append(line)
    return keywords


def normalize(text: str) -> str:
    """NFKC + casefold, without whitespace, so 「ＡＢＣ」 and "a b c" match "abc"."""
    return "".join(unicodedata.normalize("NFKC", text).casefold().split())


def transcribe(base_url: str, model: str, prompt: str, wav: bytes, timeout: float) -> str:
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "audio", "blob": base64.b64encode(wav).decode("ascii")},
                ],
            }
        ],
        "temperature": 0,
    }
    started = time.monotonic()
    response = request(f"{base_url}/chat/completions", payload, timeout=timeout)
    log(f"Inference took {time.monotonic() - started:.1f}s")
    return response["choices"][0]["message"]["content"] or ""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True, help="e.g. http://127.0.0.1:18080/v1")
    parser.add_argument("--model", required=True)
    parser.add_argument("--audio", type=Path, required=True)
    parser.add_argument("--keywords", type=Path, required=True)
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--ready-timeout", type=float, default=600)
    parser.add_argument("--request-timeout", type=float, default=900)
    parser.add_argument("--output", type=Path, help="Write the transcription here")
    parser.add_argument(
        "--allow-missing-fixture",
        action="store_true",
        help="Pass (with a warning) when the audio or keywords file does not exist yet",
    )
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/")

    try:
        wait_for_model(base_url, args.model, args.ready_timeout)
    except TimeoutError as e:
        annotate("error", str(e))
        return 1

    missing = [str(p) for p in (args.audio, args.keywords) if not p.is_file()]
    if missing:
        message = f"Transcription check skipped, fixture not found: {', '.join(missing)}"
        summary(f"### Transcription\n\n:warning: {message}")
        if args.allow_missing_fixture:
            annotate("warning", message)
            return 0
        annotate("error", message)
        return 1

    keywords = load_keywords(args.keywords)
    if not keywords:
        annotate("error", f"No keywords in {args.keywords}")
        return 1

    text = transcribe(base_url, args.model, args.prompt, args.audio.read_bytes(), args.request_timeout)
    log(f"Transcription: {text}")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")

    normalized = normalize(text)
    missing_keywords = [k for k in keywords if normalize(k) not in normalized]
    rows = "\n".join(
        f"| {k} | {'❌' if k in missing_keywords else '✅'} |" for k in keywords
    )
    summary(
        f"### Transcription\n\n```\n{text}\n```\n\n| Keyword | Found |\n| --- | --- |\n{rows}"
    )
    if missing_keywords:
        annotate("error", f"Keywords not found in transcription: {missing_keywords}")
        return 1
    log(f"All {len(keywords)} keywords found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
