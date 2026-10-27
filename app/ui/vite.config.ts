import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

// In development, /api is proxied to an audio-app started with
// TRANSCRIPT_API_ENABLED=true (override the address with AUDIO_APP_API).
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, ".", "");

  return {
    plugins: [react()],
    server: {
      proxy: {
        "/api": env.AUDIO_APP_API || "http://127.0.0.1:8000",
      },
    },
  };
});
