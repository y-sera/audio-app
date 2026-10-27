import { useMemo, useState } from "react";

import { type ConnectionState, useTranscripts } from "./useTranscripts";

const STATE_LABEL: Record<ConnectionState, string> = {
  connecting: "Connecting…",
  open: "Live",
  closed: "Disconnected",
};

const timeFormat = new Intl.DateTimeFormat(undefined, {
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
});

export default function App() {
  const { transcripts, state } = useTranscripts();
  const [filter, setFilter] = useState("");
  const [copied, setCopied] = useState(false);

  // Newest first.
  const visible = useMemo(() => {
    const query = filter.trim().toLowerCase();
    return transcripts
      .filter((t) => !query || t.text.toLowerCase().includes(query))
      .slice()
      .reverse();
  }, [transcripts, filter]);

  const copyAll = async () => {
    const text = transcripts
      .map((t) => `[${timeFormat.format(new Date(t.timestamp))}] ${t.text}`)
      .join("\n");
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard access needs a secure context (HTTPS or localhost).
    }
  };

  return (
    <div className="page">
      <header className="header">
        <div>
          <h1>Transcripts</h1>
          <p className="subtitle">
            {transcripts.length} utterance{transcripts.length === 1 ? "" : "s"}
          </p>
        </div>
        <span className={`status status-${state}`} role="status">
          <span className="dot" aria-hidden="true" />
          {STATE_LABEL[state]}
        </span>
      </header>

      <div className="toolbar">
        <input
          type="search"
          placeholder="Filter"
          aria-label="Filter transcripts"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        />
        <button type="button" onClick={copyAll} disabled={transcripts.length === 0}>
          {copied ? "Copied" : "Copy all"}
        </button>
      </div>

      {visible.length === 0 ? (
        <p className="empty">
          {transcripts.length === 0
            ? "Waiting for speech. Transcripts appear here as utterances are recognized."
            : "No transcripts match the filter."}
        </p>
      ) : (
        <ol className="list">
          {visible.map((t) => (
            <li key={t.id} className="item">
              <time dateTime={t.timestamp}>{timeFormat.format(new Date(t.timestamp))}</time>
              <p>{t.text}</p>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
