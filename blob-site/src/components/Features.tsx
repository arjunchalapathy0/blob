"use client";

import { useEffect, useRef, useState } from "react";
import { BlobFigure } from "./BlobFigure";
import { Eyebrow } from "./Chrome";
import { Glyph } from "./Glyph";
import { WingSide, wingWidth } from "./Notch";
import { notchPath } from "@/lib/notchPath";
import type { Wing } from "@/lib/notch";
import type { Mood } from "@/lib/mood";

type Item = {
  name: string;
  line: string;
  /** What the notch shows for this feature, drawn on a small screen at the top of the tile. */
  wing?: Wing;
  mood?: Mood;
  visual?: "mirror" | "lock" | "island";
  width?: "w5" | "w3";
};

const ITEMS: Item[] = [
  { name: "Now Playing", line: "Artwork, a scrubber and controls. While music plays, the notch grows art on one side and an equalizer on the other.", wing: { kind: "music" }, width: "w5" },
  { name: "Volume and brightness", line: "The keys show their level in the notch instead of the big overlay in the middle of your screen.", wing: { kind: "volume", level: 0.62 } },
  { name: "Timers", line: "A few presets, several at once, and a stopwatch. The countdown lives in the notch until it says “Time’s up”.", wing: { kind: "timer", text: "4:59" }, width: "w3" },
  { name: "Calendar", line: "Today at a glance, a countdown before meetings, and one click to join a Zoom, Meet or Teams call.", wing: { kind: "event", text: "in 8m" }, width: "w3" },
  { name: "Claude Code", line: "Working, done, or waiting on you, for each session, from hooks Blob adds to Claude Code for you.", wing: { kind: "claude", state: "waiting" }, mood: "alarmed", width: "w5" },
  { name: "Clipboard", line: "Recent copies, one click to copy again, pins for favourites. Anything from a password manager is skipped.", wing: { kind: "notice", icon: "copy", text: "Copied" } },
  { name: "Shelf", line: "Drag files onto the notch to park them. Drag them back out, AirDrop them, or show them in Finder.", wing: { kind: "notice", icon: "check", text: "3 files" } },
  { name: "Tools", line: "Keep awake, pick a colour from anywhere, screenshot to the clipboard, switch to dark mode, sleep the display.", wing: { kind: "notice", icon: "bolt", text: "Staying awake" } },
  { name: "Stats", line: "CPU, memory, network and battery, with small sparklines, and a note when the charger goes in.", wing: { kind: "notice", icon: "bolt", text: "82%" } },
  { name: "Mirror", line: "A camera preview before calls, with camera and microphone pickers. The camera runs only while you’re looking.", visual: "mirror" },
  { name: "Privacy lock", line: "Touch ID, or your password, in front of Clipboard, Shelf and Ask, if you want it.", visual: "lock" },
  { name: "On your iPhone", line: "Timers and your next event in the Dynamic Island, and your Mac’s Claude sessions in your pocket.", visual: "island" },
];

/** The closed notch with one feature's wings, drawn to fit the tile it sits in. */
function MiniNotch({ wing, mood = "idle" }: { wing: Wing; mood?: Mood }) {
  const ref = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  const ww = wingWidth(wing);
  const ear = 6;
  const width = 185 + 2 * ww + 2 * ear;
  useEffect(() => {
    const parent = ref.current?.parentElement;
    if (!parent) return;
    const fit = (w: number) => setScale(Math.min(1.06, (w - 28) / width));
    fit(parent.clientWidth);
    const ro = new ResizeObserver(([e]) => fit(e.contentRect.width));
    ro.observe(parent);
    return () => ro.disconnect();
  }, [width]);
  return (
    <div
      ref={ref}
      className="mini-notch"
      aria-hidden="true"
      style={{ width, clipPath: `path("${notchPath(0, 0, width, 32, ear, 12)}")`, transform: `translateX(-50%) scale(${scale})` }}
    >
      <div className="mini-wing" style={{ left: ear + 10, width: Math.max(0, ww - 10) }}>
        <WingSide wing={wing} side="left" mood={mood} />
      </div>
      <div className="mini-wing right" style={{ right: ear + 10, width: Math.max(0, ww - 10) }}>
        <WingSide wing={wing} side="right" mood={mood} />
      </div>
    </div>
  );
}

function Visual({ kind }: { kind: NonNullable<Item["visual"]> }) {
  if (kind === "mirror") {
    return (
      <span className="mirror" aria-hidden="true">
        <BlobFigure mood="curious" size={34} look="pointer" />
      </span>
    );
  }
  if (kind === "lock") {
    return (
      <span className="tile-icon" aria-hidden="true">
        <Glyph name="lock" size={24} />
      </span>
    );
  }
  return (
    <span className="island" aria-hidden="true">
      <BlobFigure mood="happy" size={13} look="none" />
      <span>24:23</span>
    </span>
  );
}

/** Everything else Blob does, as a grid of small screens. */
export function Features() {
  return (
    <section id="features" className="section features" aria-labelledby="features-title">
      <div className="wrap">
        <header className="section-head split">
          <div>
            <Eyebrow n="03">Everything else</Eyebrow>
            <h2 id="features-title" className="h2" data-reveal="">And it does <em>all this,</em> too.</h2>
          </div>
          <p className="lead" data-reveal="" style={{ "--d": 1 } as React.CSSProperties}>
            Twelve small things that used to need an app each. Every one of them can be switched off.
          </p>
        </header>
        <ul className="bento">
          {ITEMS.map((it, i) => (
            <li key={it.name} className={it.width ? `tile ${it.width}` : "tile"} data-reveal="" style={{ "--d": i % 3 } as React.CSSProperties}>
              {i === 2 && <div className="blob-anchor" data-blob="sit" data-blob-size="76" data-blob-x="0.78" data-blob-mood="curious" />}
              <div className={it.wing ? "tile-top" : "tile-top dark"}>
                {it.wing ? <MiniNotch wing={it.wing} mood={it.mood} /> : <Visual kind={it.visual!} />}
              </div>
              <div className="tile-copy">
                <h3 className="h3">{it.name}</h3>
                <p>{it.line}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
