"use client";

import { useEffect } from "react";
import { live } from "@/lib/notch";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** A quiet bar: name, a way to talk to Blob, a way to get it. */
export function MenuBar() {
  return (
    <header className="menubar">
      <a href="#top" className="wordmark" aria-label="Blob, back to top">Blob</a>
      <nav className="menu" aria-label="Sections">
        <a href="#demo">Try it</a>
        <a href="#scenes">Scenes</a>
        <a href="#moods">Moods</a>
        <a href="#everything">Everything</a>
      </nav>
      <a href="#get" className="menu-cta">Get Blob</a>
    </header>
  );
}

/** Blob looks where you scroll: down while you scroll down, up when you go back. */
export function PageLife() {
  useEffect(() => {
    const reduce = reducedMotion();
    let lastY = window.scrollY;
    let velocity = 0;
    return subscribe((_, dt) => {
      const y = window.scrollY;
      const v = (y - lastY) / Math.max(dt, 1 / 120);
      lastY = y;
      velocity += (v - velocity) * Math.min(1, dt * 10);
      const target = reduce ? 0 : Math.max(-0.9, Math.min(0.9, velocity / 1400));
      live.scrollLook += (target - live.scrollLook) * Math.min(1, dt * 6);
    });
  }, []);
  return null;
}
