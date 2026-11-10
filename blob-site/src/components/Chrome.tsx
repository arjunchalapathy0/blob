"use client";

import { useEffect } from "react";
import { BlobFigure } from "./BlobFigure";
import { live } from "@/lib/notch";
import { reducedMotion, subscribe } from "@/lib/ticker";

/**
 * The site's own notch: the navigation hangs from the top of the window, the way Blob's
 * notch hangs from the top of a Mac's screen. On the black rooms only its contents show.
 */
export function Nav() {
  return (
    <header className="nav">
      <a href="#top" className="nav-brand" aria-label="Blob, back to top">
        <BlobFigure mood="idle" size={15} look="pointer" />
        <span>Blob</span>
      </a>
      <nav className="nav-links" aria-label="Sections">
        <a href="#scenes">How it works</a>
        <a href="#moods">Moods</a>
        <a href="#features">Features</a>
        <a href="#privacy">Privacy</a>
      </nav>
      <a href="#get" className="nav-cta">Download</a>
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
      { rootMargin: "0px 0px -10% 0px" },
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

/** A chapter label: number, then name. */
export function Eyebrow({ n, children }: { n: string; children: React.ReactNode }) {
  return (
    <p className="eyebrow" data-reveal="">
      <b>{n}</b>
      {children}
    </p>
  );
}
