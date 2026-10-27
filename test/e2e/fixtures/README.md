# E2E fixtures

| File | Content |
| --- | --- |
| `sample.wav` | Short English utterance. 16 kHz, mono, 16-bit PCM, like the audio-app records. |
| `expected-keywords.txt` | One keyword per line (`#` starts a comment). The test passes when the transcription contains **all** of them. |

Matching ignores whitespace, letter case and full-width/half-width differences (NFKC).
Prefer a few distinctive words over a whole sentence, since the LLM's wording varies.

Until both files exist, the E2E workflow only checks that the LiteRT-LM server comes up
and lists the model, and reports the transcription check as skipped.

Convert a recording to the expected format with:

```bash
ffmpeg -i input.m4a -ac 1 -ar 16000 -sample_fmt s16 sample.wav
```
