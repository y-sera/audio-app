# Release Notes

## 0.1.0

- Initial Margo application package.
- Helm deployment profile (`audio-app` chart) and Compose deployment profile
  (`audio-app-compose` archive).
- Bundles a LiteRT-LM server running Gemma 4 E2B; the model is downloaded from
  Hugging Face on first start and cached in a persistent volume.
