# Audio Transcription App

Audio Transcription App turns speech captured by a USB microphone on an edge device
into text, entirely on the device.

## How it works

1. **Capture** – audio is read from the first input device whose name contains
   `USB Microphone` at 16 kHz, mono, 16-bit.
2. **Voice activity detection** – a Silero VAD model (ONNX) scores each 32 ms block.
   A two-threshold hysteresis starts a recording above the *start threshold* and ends it
   after a configurable silence below the *end threshold*.
3. **Transcription** – each utterance is saved as a WAV file and sent to a local
   OpenAI-compatible endpoint served by [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM)
   running Google's Gemma 4 E2B model. The transcription is written to the application log.
4. **Web UI** (optional) – a web page lists the transcripts as they are recognized, with a
   live connection indicator, a filter and copy-to-clipboard. It is served on port `30080`
   of the device by default.

## Components

| Component | Image | Role |
| --- | --- | --- |
| audio-app | `ghcr.io/y-sera/audio-app/audio-app` | Microphone capture, VAD, transcription client |
| litert-lm-bundled | `ghcr.io/y-sera/audio-app/litert-lm-bundled` | OpenAI-compatible LLM server with Gemma 4 E2B built in (model source `bundled`, default) |
| litert-lm | `ghcr.io/y-sera/audio-app/litert-lm` | The same server; downloads the model on first start (model source `download`) |
| ui | `ghcr.io/y-sera/audio-app/ui` | Web UI showing the transcripts (optional) |

## Device requirements

- amd64 or arm64 CPU with at least 2.5 cores, 4 GiB of memory and 10 GiB of storage
- A USB microphone (ALSA, `/dev/snd`)
  - Kubernetes: a device plugin that advertises `/dev/snd` as an extended resource
    (default `devic.es/audio`)
- Inference runs on the CPU by default; no GPU is required.
  - Kubernetes only: with the inference backend set to `gpu`, an NVIDIA GPU with
    Vulkan support and the `nvidia` RuntimeClass
- With the model source `download` only: internet access to Hugging Face on first start,
  to download the model (~2.5 GB). The default, `bundled`, ships the model in the image.

## Configuration

| Parameter | Default | Description |
| --- | --- | --- |
| Log Level | `INFO` | Log level of the audio-app |
| Enable Web UI | `true` | Serve the web page showing the transcripts |
| Web UI Port | `30080` | Port of the web UI on the device (30000-32767) |
| Transcription Prompt | English transcription instruction | Instruction sent with each utterance |
| Start Threshold | `0.3` | VAD speech probability that starts a recording |
| End Threshold | `0.2` | VAD speech probability below which a recording may end |
| Minimum Speech (ms) | `150` | Speech needed before a recording starts |
| Minimum Silence (ms) | `700` | Silence that ends a recording |
| Model Source | `bundled` | `bundled`: model built into the image; `download`: downloaded from Hugging Face on first start |
| Inference Backend | `cpu` | LiteRT-LM backend (`cpu` or `gpu`, Helm only) |
| Microphone Resource Name | `devic.es/audio` | Extended resource for `/dev/snd` (Helm only) |
