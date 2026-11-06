"use client";

import { useEffect, useRef, useState } from "react";
import { BlobFigure } from "./BlobFigure";
import { MOODS, type Mood } from "@/lib/mood";
import { notchPath } from "@/lib/notchPath";
import { setAmbientMood } from "@/lib/notch";

export function Moods() {
  const [mood, setMood] = useState<Mood>("idle");
  const section = useRef<HTMLElement>(null);
  const moodRef = useRef(mood);
  moodRef.current = mood;

  // The notch takes the mood you're looking at while this section is on screen.
  useEffect(() => {
    const el = section.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => e.isIntersecting && setAmbientMood(moodRef.current), { threshold: 0.4 });
    io.observe(el);
    return () => io.disconnect();
  }, []);
  useEffect(() => setAmbientMood(mood), [mood]);

  const current = MOODS.find((m) => m.mood === mood)!;

  return (
    <section id="moods" ref={section} className="section moods" data-mood={mood} aria-labelledby="moods-title">
      <div className="wrap moods-grid">
        <div className="moods-copy">
          <h2 id="moods-title" className="h2">No words. Just a face, and how it moves.</h2>
          <p className="body">
            Blob never talks in the notch. How things are going is in the way it moves: the same six moods, the same
            springs, the same blink every 4.6 seconds as the app.
          </p>
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
          <p className="body mood-when" aria-live="polite">{current.when}</p>
        </div>
        <div className="mood-stage">
          <span className="bezel" aria-hidden="true" />
          <svg className="mood-notch" viewBox="0 0 560 330" aria-hidden="true">
            <path d={notchPath(0, 0, 560, 330, 18, 64)} fill="var(--notch)" />
          </svg>
          <div className="mood-blob">
            <BlobFigure mood={mood} size={150} look="pointer" label={`Blob, ${current.name.toLowerCase()}`} />
          </div>
        </div>
      </div>
    </section>
  );
}
