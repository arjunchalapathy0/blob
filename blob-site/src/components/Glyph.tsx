/**
 * Small monochrome line glyphs, drawn for this site (the app uses SF Symbols, which can't ship
 * on the web). 16×16 grid, 1.6 stroke, round caps.
 */
const paths: Record<string, string> = {
  mic: "M8 2.2a2.2 2.2 0 0 1 2.2 2.2v3.4a2.2 2.2 0 1 1-4.4 0V4.4A2.2 2.2 0 0 1 8 2.2Z M4 7.6a4 4 0 0 0 8 0 M8 11.6v2.2",
  check: "M3.4 8.4l3 3 6.2-6.6",
  warn: "M8 2.5l6 10.5H2L8 2.5Z M8 6.6v3 M8 11.3v.1",
  ear: "M5 6.2a3 3 0 1 1 5.8 1.1c-.6 1.4-2 1.8-2 3.4a1.8 1.8 0 0 1-3.4.7",
  bolt: "M9 1.8L3.8 9h4l-1 5.2L12.2 7h-4L9 1.8Z",
  copy: "M5.5 5.5h7v7h-7z M3.5 10.5v-7h7",
  timer: "M8 14a5.2 5.2 0 1 0 0-10.4A5.2 5.2 0 0 0 8 14Z M8 6v3l1.8 1.2 M6.4 1.8h3.2",
  speaker: "M2.5 6.2h2.2L8 3.5v9L4.7 9.8H2.5z M10.4 6a2.8 2.8 0 0 1 0 4 M12 4.4a5 5 0 0 1 0 7.2",
  calendar: "M3 4h10v9.5H3z M3 7h10 M5.6 2.5V5 M10.4 2.5V5",
  music: "M6 12.2a1.8 1.8 0 1 1-1.8-1.8H6V3.2l6-1.2v8.4a1.8 1.8 0 1 1-1.8-1.8H12",
  tray: "M2.5 9.5h3l1 1.8h3l1-1.8h3 M2.5 9.5 4 3.5h8l1.5 6v3.5h-11z",
  clipboard: "M5 3h6v1.8H5z M4 3.6H3v10.4h10V3.6h-1 M5.5 8h5 M5.5 10.6h3",
  sparkle: "M8 2c.4 3 1.6 4.6 5 6-3.4 1.4-4.6 3-5 6-.4-3-1.6-4.6-5-6 3.4-1.4 4.6-3 5-6Z",
  grid: "M3 3h4v4H3z M9 3h4v4H9z M3 9h4v4H3z M9 9h4v4H9z",
  gauge: "M2.8 11.5a5.4 5.4 0 1 1 10.4 0 M8 10.2l2.6-3.4",
  camera: "M2.5 5h2.2l1.2-1.6h4.2L11.3 5h2.2v7.5h-11z M8 11a2.2 2.2 0 1 0 0-4.4A2.2 2.2 0 0 0 8 11Z",
  waveform: "M2.5 8v0 M5 5.5v5 M7.5 3v10 M10 5.5v5 M12.5 7v2",
  stop: "",
  up: "M8 13V3.5 M3.8 7.7 8 3.5l4.2 4.2",
  plus: "M8 3.5v9 M3.5 8h9",
  play: "",
  trash: "M3 4.5h10 M6.2 4.5V3h3.6v1.5 M4.3 4.5l.7 9h6l.7-9",
};

export function Glyph({ name, size = 16, className }: { name: string; size?: number; className?: string }) {
  if (name === "stop") {
    return (
      <svg width={size} height={size} viewBox="0 0 16 16" className={className} aria-hidden="true">
        <rect x="4" y="4" width="8" height="8" rx="1.6" fill="currentColor" />
      </svg>
    );
  }
  if (name === "play") {
    return (
      <svg width={size} height={size} viewBox="0 0 16 16" className={className} aria-hidden="true">
        <path d="M5 3.2v9.6L12.8 8 5 3.2Z" fill="currentColor" />
      </svg>
    );
  }
  if (name === "checkCircle") {
    return (
      <svg width={size} height={size} viewBox="0 0 16 16" className={className} aria-hidden="true">
        <circle cx="8" cy="8" r="6.8" fill="currentColor" />
        <path d="M5 8.3l2 2 4-4.3" fill="none" stroke="#000" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" className={className} aria-hidden="true" fill="none"
      stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d={paths[name] ?? ""} />
    </svg>
  );
}
