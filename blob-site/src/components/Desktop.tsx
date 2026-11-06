"use client";

import { useEffect, useRef } from "react";
import { BlobFigure } from "./BlobFigure";
import { Equalizer } from "./Bars";
import { Glyph } from "./Glyph";
import { useSpringIn } from "@/lib/useSpring";
import { Spring, Springs } from "@/lib/spring";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** What's on the desktop. Each request or scene changes a few of these. */
export type DesktopState = {
  player: "hidden" | "open" | "playing";
  music: boolean;
  musicTitle: string;
  shortcut: boolean;
  calendar: boolean;
  terminal: "hidden" | "port" | "build" | "claude";
  scan: number; // bump to play the screenshot sweep
  explained: boolean;
  trash: "full" | "empty";
  trashBadge: boolean;
  downloads: boolean;
  asked: boolean;
};

export const EMPTY_DESKTOP: DesktopState = {
  player: "hidden",
  music: false,
  musicTitle: "Calm",
  shortcut: false,
  calendar: false,
  terminal: "port",
  scan: 0,
  explained: false,
  trash: "full",
  trashBadge: true,
  downloads: false,
  asked: false,
};

function Win({
  shown, className, title, children, preset, y, label,
}: {
  shown: number; className: string; title: string; children: React.ReactNode;
  preset?: (typeof Springs)[keyof typeof Springs]; y?: number; label?: string;
}) {
  const ref = useSpringIn<HTMLDivElement>(shown, { preset: preset ?? Springs.open, y: y ?? 36 });
  return (
    <div ref={ref} className={`win ${className}`} style={{ opacity: 0 }} role="group" aria-label={label ?? title}>
      <div className="win-bar">
        <span className="lights" aria-hidden="true"><i /><i /><i /></span>
        <span className="win-title">{title}</span>
      </div>
      <div className="win-body">{children}</div>
    </div>
  );
}

function Player({ playing }: { playing: boolean }) {
  const bar = useRef<HTMLSpanElement>(null);
  const frame = useRef<HTMLDivElement>(null);
  const playingRef = useRef(playing);
  playingRef.current = playing;
  useEffect(() => {
    const reduce = reducedMotion();
    let progress = 0.02;
    return subscribe((t, dt) => {
      if (!playingRef.current) return;
      if (!reduce) progress = Math.min(1, progress + dt / 1440);
      if (bar.current) bar.current.style.transform = `scaleX(${progress})`;
      if (frame.current && !reduce && playingRef.current) {
        frame.current.style.setProperty("--pan", `${Math.sin(t * 0.21) * 6}%`);
      }
    });
  }, []);
  return (
    <div className="player">
      <div className="player-frame" ref={frame}>
        <span className="player-sky" />
        <span className="player-wall" />
        <span className="player-wall two" />
        <span className="player-caption">Episode 3</span>
        {!playing && <span className="player-play"><Glyph name="play" size={22} /></span>}
      </div>
      <div className="player-bar"><span ref={bar} /></div>
    </div>
  );
}

export function Desktop({ s, label }: { s: DesktopState; label: string }) {
  const scan = useRef<HTMLDivElement>(null);
  const trashLid = useRef<HTMLSpanElement>(null);

  // The screenshot sweep: a hairline passes over the screen once, the way a capture "happens".
  useEffect(() => {
    if (!s.scan) return;
    const el = scan.current;
    if (!el || reducedMotion()) return;
    const sp = new Spring(0, Springs.soft);
    sp.to(1);
    const unsub = subscribe((_, dt) => {
      const v = sp.step(dt);
      el.style.transform = `translateY(${v * 100}%)`;
      el.style.opacity = String(v < 0.98 ? 1 : 0);
      if (sp.settled) unsub();
    });
    return unsub;
  }, [s.scan]);

  // The trash lid wobbles when it empties (Springs.wobble).
  useEffect(() => {
    if (s.trash !== "empty" || reducedMotion()) return;
    const el = trashLid.current;
    if (!el) return;
    const sp = new Spring(-18, Springs.wobble);
    sp.to(0);
    const unsub = subscribe((_, dt) => {
      el.style.transform = `rotate(${sp.step(dt)}deg)`;
      if (sp.settled) unsub();
    });
    return unsub;
  }, [s.trash]);

  return (
    <div className="stage" role="img" aria-label={label}>

      <Win shown={s.terminal !== "hidden" ? 1 : 0} className="w-terminal" title="Terminal" preset={Springs.soft} y={18}>
        {s.terminal === "port" && (
          <pre className={s.explained ? "term explained" : "term"}>
            <span className="t-dim">~/site $</span> npm run dev{"\n"}
            <span className="t-dim">&gt; next dev</span>{"\n\n"}
            <mark>Error: listen EADDRINUSE: address already in use :::3000</mark>{"\n"}
            <span className="t-dim">    at Server.setupListenHandle (node:net:1898:16)</span>
          </pre>
        )}
        {s.terminal === "build" && (
          <pre className={s.explained ? "term explained" : "term"}>
            <span className="t-dim">~/app $</span> npm run build{"\n\n"}
            <mark>Error: Incompatible React versions: react 19.1.0, react-dom 18.3.1</mark>{"\n"}
            <span className="t-dim">Build failed because of webpack errors</span>
          </pre>
        )}
        {s.terminal === "claude" && (
          <pre className="term">
            <span className="t-dim">~/blob $</span> claude{"\n\n"}
            <span className="t-dim">● Editing NotchShape.swift</span>{"\n"}
            <span className="t-dim">● Running the tests</span>{"\n\n"}
            Allow Claude to run <mark>xcodebuild test</mark>? (y/n)
          </pre>
        )}
      </Win>

      <Win shown={s.player !== "hidden" ? 1 : 0} className={s.player === "playing" ? "w-player full" : "w-player"} title="Attack on Titan, Episode 3" label="Safari, playing Attack on Titan episode 3">
        <Player playing={s.player === "playing"} />
      </Win>

      <Win shown={s.music ? 1 : 0} className="w-music" title="Music" preset={Springs.open}>
        <div className="music">
          <span className="music-art" aria-hidden="true"><i /><i /><i /></span>
          <span className="music-meta">
            <strong>{s.musicTitle}</strong>
            <span>Playing in Music</span>
          </span>
          <Equalizer />
        </div>
      </Win>

      <Win shown={s.calendar ? 1 : 0} className="w-calendar" title="Calendar" preset={Springs.soft}>
        <div className="cal">
          <span className="cal-day">Thursday</span>
          <span className="cal-row"><b>9:30</b> Standup</span>
          <span className="cal-row"><b>11:00</b> Design review</span>
          <span className="cal-row"><b>14:00</b> Focus</span>
        </div>
      </Win>

      <Win shown={s.downloads ? 1 : 0} className="w-downloads" title="Downloads" preset={Springs.soft}>
        <div className="files" aria-hidden="true">
          {Array.from({ length: 12 }, (_, i) => <i key={i} />)}
        </div>
        <p className="files-note">1,284 items</p>
      </Win>

      <Toast shown={s.shortcut} />
      <Toast shown={s.asked} kind="ask" />

      <div className="dock" aria-hidden="true">
        <span className="trash">
          <span ref={trashLid} className="trash-lid" />
          <span className="trash-can" data-empty={s.trash === "empty" || undefined} />
          {s.trash === "full" && s.trashBadge && <span className="badge">214</span>}
        </span>
      </div>

      <div ref={scan} className="scan" aria-hidden="true" />
    </div>
  );
}

function Toast({ shown, kind = "shortcut" }: { shown: boolean; kind?: "shortcut" | "ask" }) {
  const ref = useSpringIn<HTMLDivElement>(shown ? 1 : 0, { preset: Springs.wobble, y: -16, scale: 0.94 });
  return (
    <div ref={ref} className={`toast ${kind}`} style={{ opacity: 0 }}>
      {kind === "shortcut" ? (
        <>
          <span className="toast-icon"><Glyph name="grid" size={14} /></span>
          <span><strong>Morning</strong><br />Focus on. Calendar open.</span>
        </>
      ) : (
        <>
          <span className="toast-icon dark"><BlobFigure mood="curious" size={14} look="none" /></span>
          <span><strong>Before I do that</strong><br />It can’t be undone.</span>
        </>
      )}
    </div>
  );
}
