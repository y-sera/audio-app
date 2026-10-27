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

## Components

| Component | Image | Role |
| --- | --- | --- |
| audio-app | `ghcr.io/y-sera/audio-app/audio-app` | Microphone capture, VAD, transcription client |
| litert-lm | `ghcr.io/y-sera/audio-app/litert-lm` | OpenAI-compatible LLM server (Gemma 4 E2B) |

## Device requirements

- amd64 CPU with at least 2.5 cores, 4 GiB of memory and 10 GiB of storage
- A USB microphone (ALSA, `/dev/snd`)
- An NVIDIA GPU with Vulkan support
  - Kubernetes: the `nvidia` RuntimeClass, and a device plugin that advertises
    `/dev/snd` as an extended resource (default `devic.es/audio`)
  - Compose: the NVIDIA Container Toolkit
- Internet access to Hugging Face on first start, to download the model (~2.5 GB)

## Configuration

| Parameter | Default | Description |
| --- | --- | --- |
| Log Level | `INFO` | Log level of the audio-app |
| Transcription Prompt | Japanese transcription instruction | Instruction sent with each utterance |
| Start Threshold | `0.3` | VAD speech probability that starts a recording |
| End Threshold | `0.2` | VAD speech probability below which a recording may end |
| Minimum Speech (ms) | `150` | Speech needed before a recording starts |
| Minimum Silence (ms) | `700` | Silence that ends a recording |
| Inference Backend | `gpu` | LiteRT-LM backend (`gpu` or `cpu`) |
| Microphone Resource Name | `devic.es/audio` | Extended resource for `/dev/snd` (Helm only) |
