"use client";

import { useEffect, useRef } from "react";
import { live } from "@/lib/notch";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** A quiet bar: the name, the chapters, a way to get it, and how far through the story you are. */
export function MenuBar() {
  const progress = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    let last = -1;
    return subscribe(() => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const p = max > 0 ? Math.round((window.scrollY / max) * 1000) / 1000 : 0;
      if (p !== last && progress.current) {
        progress.current.style.transform = `scaleX(${p})`;
        last = p;
      }
    });
  }, []);
  return (
    <header className="menubar">
      <a href="#top" className="wordmark" aria-label="Blob, back to top">Blob</a>
      <nav className="menu" aria-label="Chapters">
        <a className="link" href="#demo">Try it</a>
        <a className="link" href="#scenes">A day</a>
        <a className="link" href="#moods">Moods</a>
        <a className="link" href="#everything">Everything</a>
        <a className="link" href="#privacy">Privacy</a>
      </nav>
      <a href="#get" className="menu-cta">Get Blob</a>
      <span ref={progress} className="menubar-progress" aria-hidden="true" />
    </header>
  );
}

/**
 * Page-wide life: Blob looks where you scroll, and anything marked data-reveal arrives once
 * it scrolls into view (once, not every time).
 */
export function PageLife() {
  useEffect(() => {
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            io.unobserve(e.target);
          }
        }
      },
      { rootMargin: "0px 0px -12% 0px" },
    );
    document.querySelectorAll("[data-reveal]").forEach((n) => io.observe(n));

    const reduce = reducedMotion();
    let lastY = window.scrollY;
    let velocity = 0;
    const unsub = subscribe((_, dt) => {
      const y = window.scrollY;
      const v = (y - lastY) / Math.max(dt, 1 / 120);
      lastY = y;
      velocity += (v - velocity) * Math.min(1, dt * 10);
      const target = reduce ? 0 : Math.max(-0.9, Math.min(0.9, velocity / 1400));
      live.scrollLook += (target - live.scrollLook) * Math.min(1, dt * 6);
    });
    return () => {
      io.disconnect();
      unsub();
    };
  }, []);
  return null;
}

/** A chapter label: number, then name. The story is told in chapters. */
export function Eyebrow({ n, children }: { n: string; children: React.ReactNode }) {
  return (
    <p className="eyebrow" data-reveal="">
      <b>{n}</b>
      {children}
    </p>
  );
}
