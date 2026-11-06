"use client";

import { useEffect, useRef } from "react";
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
    <section id="everything" className="section everything" data-mood="curious" aria-labelledby="everything-title">
      <div className="wrap">
        <div className="section-head">
          <h2 id="everything-title" className="h2">Everything else that lives up there.</h2>
          <p className="body">
            Point at any of these and the notch above will show you what it looks like. Each one can be switched off in
            Settings.
          </p>
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
