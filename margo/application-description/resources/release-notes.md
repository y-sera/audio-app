# Release Notes

## 0.2.0

- New optional web UI (Vite + React on nginx) that lists the transcripts as they are
  recognized, with a live connection indicator, a filter and copy-to-clipboard.
  - Parameters `uiEnabled` (default on) and `uiPort` (default 30080).
  - Helm: `ui.enabled`, exposed as a NodePort service. Compose: `ui` service on `UI_PORT`.
  - The audio-app serves a read-only transcript API for the UI only when it is enabled.
  - The UI has no authentication; anyone who can reach the port can read the transcripts.
- LiteRT-LM memory limit lowered from 6000Mi to 3000Mi (request 2000Mi).

## 0.1.1

- Default transcription prompt is now English (instruction and output).
- Inference runs on the CPU by default; GPU is optional (Helm `llm.model.backend=gpu`).
- Multi-arch images for amd64 and arm64.
- Dependency updates: openai 3.37.0, onnxruntime 1.31.0, numpy 2.5.4, uv_build 0.13.
- Pinned LiteRT-LM 0.18.1 and uv 0.13.6 in the images.

## 0.1.0

- Initial Margo application package.
- Helm deployment profile (`audio-app` chart) and Compose deployment profile
  (`audio-app-compose` archive).
- Bundles a LiteRT-LM server running Gemma 4 E2B; the model is downloaded from
  Hugging Face on first start and cached in a persistent volume.
