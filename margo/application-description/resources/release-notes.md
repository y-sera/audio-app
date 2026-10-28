# Release Notes

## 0.1.2

- Compose: the LiteRT-LM health check start period is raised from 10 minutes to
  30 minutes, so a slow first-start model download no longer marks the service unhealthy.

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
