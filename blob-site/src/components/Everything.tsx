"use client";

import { useEffect, useRef } from "react";
import { Eyebrow } from "./Chrome";
import { Notch } from "./Notch";
import { useNotchScale } from "@/lib/useNotchScale";
import { releaseNotch, setNotch, takeNotch, type Wing } from "@/lib/notch";
import type { Mood } from "@/lib/mood";

type Item = { name: string; line: string; wing?: Wing; mood?: Mood; open?: boolean };

const ITEMS: Item[] = [
  { name: "Now Playing", line: "Artwork, scrubber and controls. While music plays, the notch grows art on one side and an equalizer on the other.", wing: { kind: "music" } },
  { name: "Volume and brightness", line: "The keys show their level in the notch instead of the big overlay in the middle of your screen.", wing: { kind: "volume", level: 0.62 } },
  { name: "Timers", line: "A few presets, several at once, and a stopwatch. The countdown lives in the notch until it says “Time’s up”.", wing: { kind: "timer", text: "4:59" } },
  { name: "Calendar", line: "Today at a glance, a countdown before meetings, and one click to join a Zoom, Meet or Teams call.", wing: { kind: "event", text: "in 8m" } },
  { name: "Claude Code", line: "Working, done, or waiting on you, for each session, from hooks Blob adds to Claude Code for you.", wing: { kind: "claude", state: "waiting" } },
  { name: "Clipboard", line: "Recent copies, one click to copy again, pins for favourites. Anything from a password manager is skipped.", wing: { kind: "notice", icon: "copy", text: "Copied" } },
  { name: "Shelf", line: "Drag files onto the notch to park them. Drag them back out, AirDrop them, or show them in Finder.", wing: { kind: "notice", icon: "check", text: "3 files" } },
  { name: "Tools", line: "Keep awake, pick a colour from anywhere, screenshot to the clipboard, switch to dark mode, sleep the display." , wing: { kind: "notice", icon: "bolt", text: "Staying awake" } },
  { name: "Stats", line: "CPU, memory, network and battery, with small sparklines, and a note when the charger goes in." , wing: { kind: "notice", icon: "bolt", text: "82%" } },
  { name: "Mirror", line: "A camera preview before calls, with camera and microphone pickers. The camera runs only while you’re looking.", mood: "curious" },
  { name: "Privacy lock", line: "Touch ID, or your password, in front of Clipboard, Shelf and Ask, if you want it.", mood: "sleepy" },
  { name: "On your iPhone", line: "Timers and your next event in the Dynamic Island, and your Mac’s Claude sessions in your pocket.", mood: "happy" },
];

export function Everything() {
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const scale = useNotchScale(1.1, 0.42);

  const show = (item: Item) => {
    takeNotch("index", () => timer.current && clearInterval(timer.current));
    if (timer.current) clearInterval(timer.current);
    setNotch({ open: false, wing: item.wing ?? { kind: "none" }, mood: item.mood ?? "curious" });
    if (item.wing?.kind === "timer") {
      let s = 299;
      timer.current = setInterval(() => {
        s -= 1;
        if (s < 290) {
          s = 299;
        }
        setNotch({ wing: { kind: "timer", text: `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}` } });
      }, 1000);
    }
  };
  const hide = () => {
    if (timer.current) clearInterval(timer.current);
    releaseNotch("index", "curious");
  };
  useEffect(() => () => {
    if (timer.current) clearInterval(timer.current);
  }, []);

  return (
    <section id="everything" className="section everything" aria-labelledby="everything-title">
      <div className="wrap everything-grid">
        <div className="everything-side">
          <Eyebrow n="05">Everything else</Eyebrow>
          <h2 id="everything-title" className="h2" data-reveal="">And it does <em>all this,</em> too.</h2>
          <p className="body" data-reveal="" style={{ "--d": 2 } as React.CSSProperties}>Point at one and the notch shows you. Every one of them can be switched off.</p>
          <div className="mac small sticky-mac">
            <div className="blob-anchor" data-blob="sit" data-blob-size="84" data-blob-x="0.82" data-blob-mood="notch" />
            <div className="mac-screen short">
              <Notch scale={scale} label="The notch, showing the feature you point at" />
            </div>
          </div>
        </div>
        <ul className="index" onPointerLeave={hide}>
          {ITEMS.map((it) => (
            <li key={it.name}>
              <button
                type="button"
                className="index-row"
                onPointerEnter={() => show(it)}
                onFocus={() => show(it)}
                onBlur={hide}
                onClick={() => show(it)}
              >
                <span className="index-name">{it.name}</span>
                <span className="index-line">{it.line}</span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
