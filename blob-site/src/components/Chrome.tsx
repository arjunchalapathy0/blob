"use client";

import { useEffect, useState } from "react";
import { live, setAmbientMood } from "@/lib/notch";
import { reducedMotion, subscribe } from "@/lib/ticker";
import type { Mood } from "@/lib/mood";

/** The thin menu-bar strip the notch hangs from. */
export function MenuBar() {
  const [theme, setTheme] = useState<"light" | "dark" | null>(null);
  useEffect(() => {
    const t = document.documentElement.dataset.theme as "light" | "dark" | undefined;
    setTheme(t ?? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));
  }, []);
  const flip = () => {
    const next = theme === "dark" ? "light" : "dark";
    setTheme(next);
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem("theme", next);
    } catch {}
  };
  return (
    <header className="menubar">
      <a href="#top" className="wordmark" aria-label="Blob, back to top">Blob</a>
      <nav className="menu" aria-label="Sections">
        <a href="#scenes">Scenes</a>
        <a href="#moods">Moods</a>
        <a href="#everything">Everything</a>
        <a href="#privacy">Privacy</a>
      </nav>
      <button type="button" className="talk" onClick={() => window.dispatchEvent(new Event("blob:focus-notch"))}>
        Talk to Blob
      </button>
      <div className="menu-right">
        <button type="button" className="theme" onClick={flip} aria-label={theme === "dark" ? "Use the light appearance" : "Use the dark appearance"}>
          <span className={theme === "dark" ? "moon" : "sun"} aria-hidden="true" />
        </button>
        <a href="#get" className="menu-cta">Get Blob</a>
      </div>
    </header>
  );
}

/**
 * Blob reacts to the page: it looks where you scroll, and takes the mood of the section
 * you're reading (data-mood on each section), falling asleep at the footer.
 */
export function PageLife() {
  useEffect(() => {
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

    const sections = Array.from(document.querySelectorAll<HTMLElement>("[data-mood]"));
    const visible = new Map<Element, number>();
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => visible.set(e.target, e.isIntersecting ? e.intersectionRatio : 0));
        let best: HTMLElement | null = null;
        let ratio = 0;
        visible.forEach((r, el) => {
          if (r > ratio) {
            ratio = r;
            best = el as HTMLElement;
          }
        });
        if (best) setAmbientMood(((best as HTMLElement).dataset.mood as Mood) ?? "idle");
      },
      { threshold: [0, 0.25, 0.5, 0.75, 1] },
    );
    sections.forEach((s) => io.observe(s));
    return () => {
      unsub();
      io.disconnect();
    };
  }, []);
  return null;
}
