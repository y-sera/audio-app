import { useEffect, useState } from "react";

export interface Transcript {
  id: number;
  utterance: number;
  text: string;
  timestamp: string;
}

export type ConnectionState = "connecting" | "open" | "closed";

// Subscribes to the audio-app transcript stream. The server sends a
// "snapshot" event with the recent transcripts on every (re)connection,
// so the list is simply replaced, then a "transcript" event per new one.
export function useTranscripts(url = "/api/events") {
  const [transcripts, setTranscripts] = useState<Transcript[]>([]);
  const [state, setState] = useState<ConnectionState>("connecting");

  useEffect(() => {
    const source = new EventSource(url);

    source.onopen = () => setState("open");
    // EventSource reconnects by itself; show it while it does.
    source.onerror = () =>
      setState(source.readyState === EventSource.CLOSED ? "closed" : "connecting");

    source.addEventListener("snapshot", (event) => {
      const data = JSON.parse((event as MessageEvent<string>).data) as {
        transcripts: Transcript[];
      };
      setTranscripts(data.transcripts);
    });

    source.addEventListener("transcript", (event) => {
      const item = JSON.parse((event as MessageEvent<string>).data) as Transcript;
      setTranscripts((current) =>
        current.some((t) => t.id === item.id) ? current : [...current, item],
      );
    });

    return () => source.close();
  }, [url]);

  return { transcripts, state };
}
