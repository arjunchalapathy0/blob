"use client";

import { useState } from "react";
import { MOODS, type Mood } from "@/lib/mood";

/** Blob, centre stage and big, in whichever mood you pick. */
export function Moods() {
  const [mood, setMood] = useState<Mood>("happy");
  const current = MOODS.find((m) => m.mood === mood)!;

  return (
    <section id="moods" className="section moods" aria-labelledby="moods-title">
      <div className="wrap">
        <div className="moods-head">
          <h2 id="moods-title" className="h2">It never says a word.</h2>
          <p className="body">
            Blob talks with its whole body: six moods, the app’s own springs, a blink every 4.6 seconds. Pick one.
          </p>
        </div>
        <div className="mood-stage">
          <span className="mood-word" aria-hidden="true">{current.name}</span>
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
