"use client";

import { useEffect, useRef, useState } from "react";
import { Eyebrow } from "./Chrome";
import { MOODS, type Mood } from "@/lib/mood";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** Blob, centre stage and big on a sheet of paper, in whichever mood you pick. */
export function Moods() {
  const [mood, setMood] = useState<Mood>("happy");
  const current = MOODS.find((m) => m.mood === mood)!;
  const stage = useRef<HTMLDivElement>(null);
  const word = useRef<HTMLSpanElement>(null);

  // The mood's name drifts sideways behind Blob as the section scrolls past.
  useEffect(() => {
    const el = stage.current;
    if (!el || reducedMotion()) return;
    let visible = false;
    let pending = true;
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
      pending = true;
    });
    io.observe(el);
    const mark = () => (pending = true);
    window.addEventListener("scroll", mark, { passive: true });
    const unsub = subscribe(() => {
      if (!visible || !pending) return;
      pending = false;
      const r = el.getBoundingClientRect();
      const p = (r.top + r.height / 2) / window.innerHeight - 0.5;
      if (word.current) word.current.style.transform = `translateX(${(p * 9).toFixed(2)}%)`;
    });
    return () => {
      unsub();
      io.disconnect();
      window.removeEventListener("scroll", mark);
    };
  }, []);

  return (
    <section id="moods" className="section paper moods" aria-labelledby="moods-title">
      <div className="wrap">
        <header className="section-head center">
          <Eyebrow n="02">Moods</Eyebrow>
          <h2 id="moods-title" className="h2" data-reveal="">It never says <em>a word.</em></h2>
          <p className="lead" data-reveal="" style={{ "--d": 1 } as React.CSSProperties}>
            Blob talks with its whole body: six moods, the app’s own springs, a blink every 4.6 seconds. Pick one.
          </p>
        </header>
        <div ref={stage} className="mood-stage">
          <span ref={word} className="mood-word" data-word={current.name} aria-hidden="true" />
          <div className="blob-anchor mood-anchor" data-blob="center" data-blob-size="300" data-blob-mood={mood} data-blob-priority="400" />
        </div>
        <div className="mood-list" role="radiogroup" aria-label="Moods">
          {MOODS.map((m) => (
            <button
              key={m.mood}
              type="button"
              role="radio"
              aria-checked={m.mood === mood}
              className={m.mood === mood ? "mood on" : "mood"}
              onClick={() => setMood(m.mood)}
            >
              {m.name}
            </button>
          ))}
        </div>
        <p className="mood-when" aria-live="polite">{current.when}</p>
      </div>
    </section>
  );
}
