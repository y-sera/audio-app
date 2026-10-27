# audio-app UI

Web page that lists the transcripts of the audio-app as they are recognized
(Vite + React + TypeScript, served by nginx).

It reads the read-only transcript API of the audio-app, which runs when
`TRANSCRIPT_API_ENABLED=true`:

| Endpoint | Content |
| --- | --- |
| `GET /api/transcripts` | Recent transcripts as JSON |
| `GET /api/events` | Server-Sent Events: `snapshot` (recent transcripts) on connect, then `transcript` per new one |

## Development

```bash
npm ci
npm run dev     # proxies /api to http://127.0.0.1:8000 (override with AUDIO_APP_API)
npm run build   # type check + production build into dist/
```

## Container

| Variable | Default | Description |
| --- | --- | --- |
| `API_UPSTREAM` | `audio-app:8000` | `host:port` of the audio-app transcript API |
| `UI_ENABLED` | `true` | `false` keeps the container running without serving (used by Compose) |

nginx listens on port 8080 as a non-root user.
