"use client";

import { useEffect, useRef } from "react";
import { BlobFigure } from "./BlobFigure";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** The iPhone companion: a Live Activity in the Dynamic Island, and a Lock Screen card. */
export function Phone() {
  const digits = useRef<HTMLSpanElement>(null);
  const bar = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    const total = 25 * 60;
    const start = performance.now() / 1000;
    const reduce = reducedMotion();
    let last = "";
    return subscribe((t) => {
      const left = Math.max(0, total - 37 - (reduce ? 0 : t - start));
      const text = `${Math.floor(left / 60)}:${String(Math.floor(left % 60)).padStart(2, "0")}`;
      const changed = text !== last;
      if (changed && digits.current) digits.current.textContent = text;
      if (changed && bar.current) bar.current.style.transform = `scaleX(${(1 - left / total).toFixed(4)})`;
      last = text;
    });
  }, []);

  return (
    <section id="iphone" className="section phone-section" data-mood="happy" aria-labelledby="phone-title">
      <div className="wrap phone-grid">
        <div className="phone-copy">
          <h2 id="phone-title" className="h2">A little of it comes with you.</h2>
          <p className="body">
            The iPhone app puts your timers and your next meeting in the Dynamic Island and on the Lock Screen. Pair it
            with your Mac using a six-digit code on the same Wi-Fi, and you can see Claude working from the couch, or
            type your Mac a task and watch it happen.
          </p>
        </div>
        <div className="phone" role="img" aria-label="An iPhone Lock Screen with a Blob timer in the Dynamic Island">
          <div className="phone-screen">
            <div className="island">
              <BlobFigure mood="happy" size={13} look="none" />
              <span ref={digits} className="island-digits">24:23</span>
            </div>
            <p className="phone-date">Thursday 6 November</p>
            <p className="phone-time">9:41</p>
            <div className="activity">
              <BlobFigure mood="idle" size={30} look="pointer" />
              <span className="activity-text">
                <span className="activity-kicker">Timer</span>
                <strong>25 min</strong>
              </span>
              <span className="activity-bar"><span ref={bar} /></span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
