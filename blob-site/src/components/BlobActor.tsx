"use client";

import { useEffect, useRef, useState } from "react";
import { BlobFigure } from "./BlobFigure";
import { displayMood } from "./Notch";
import { getNotch, live } from "@/lib/notch";
import type { Mood } from "@/lib/mood";
import { Spring } from "@/lib/spring";
import { reducedMotion, subscribe } from "@/lib/ticker";

/**
 * The lead: one big Blob that lives on top of the page and moves between anchors.
 *
 * An anchor is any element with class "blob-anchor" and:
 *   data-blob="sit"     Blob stands on the element's top edge
 *   data-blob="center"  Blob stands in the middle of the element
 *   data-blob-size      height in px on desktop (scaled down on small screens)
 *   data-blob-x         0…1 across the element (default 0.5)
 *   data-blob-mood      a mood, or "notch" to feel what the notch feels
 *   data-blob-off       present = ignore for now
 * The anchor nearest the middle of the screen wins. Blob travels between anchors on a loose
 * spring (and squashes and leans as it goes), then follows its perch tightly.
 */
const BASE = 240;
const TRAVEL = { response: 0.62, damping: 0.6 };
const FOLLOW = { response: 0.14, damping: 0.92 };

export function BlobActor() {
  const wrap = useRef<HTMLDivElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const lookRef = useRef({ x: 0, y: 0 });
  const [mood, setMood] = useState<Mood>("idle");
  const moodRef = useRef<Mood>("idle");

  useEffect(() => {
    const reduce = reducedMotion();
    const anchors = document.getElementsByClassName("blob-anchor") as HTMLCollectionOf<HTMLElement>;
    const x = new Spring(window.innerWidth / 2, TRAVEL);
    const y = new Spring(window.innerHeight * 0.6, TRAVEL);
    const size = new Spring(120, TRAVEL);
    const shown = new Spring(0, { response: 0.35, damping: 0.9 });
    let current: HTMLElement | null = null;
    let travelUntil = 0;
    let started = false;
    // Measure perches only when something moved (scroll, resize, a click that changes state).
    let rects: { a: HTMLElement; r: DOMRect }[] = [];
    let dirty = true;
    let frames = 0;
    const mark = () => (dirty = true);
    window.addEventListener("scroll", mark, { passive: true });
    window.addEventListener("resize", mark, { passive: true });
    window.addEventListener("pointerup", mark, { passive: true });

    const unsub = subscribe((t, dt) => {
      const vh = window.innerHeight;
      const vw = window.innerWidth;
      const k = vw < 700 ? 0.62 : vw < 1100 ? 0.82 : 1;

      if (dirty || ++frames % 30 === 0) {
        rects = [];
        for (let i = 0; i < anchors.length; i++) {
          const a = anchors[i];
          if (a.dataset.blobOff === undefined) rects.push({ a, r: a.getBoundingClientRect() });
        }
        dirty = false;
      }
      // Pick the anchor nearest the middle of the screen.
      let best: HTMLElement | null = null;
      let bestRect: DOMRect | null = null;
      let bestD = Infinity;
      for (const { a, r } of rects) {
        if (a.dataset.blobOff !== undefined) continue;
        if (r.bottom < vh * 0.08 || r.top > vh * 0.92 || r.width === 0) continue;
        const cy = r.top + r.height / 2;
        const d = Math.abs(cy - vh * 0.5) - Number(a.dataset.blobPriority ?? 0);
        if (d < bestD) {
          bestD = d;
          best = a;
          bestRect = r;
        }
      }

      if (best && bestRect) {
        const s = Number(best.dataset.blobSize ?? 120) * k;
        const fx = Number(best.dataset.blobX ?? 0.5);
        const tx = bestRect.left + bestRect.width * fx;
        const ty = best.dataset.blob === "center" ? bestRect.top + bestRect.height / 2 + s / 2 : bestRect.top;
        const now = performance.now();
        if (best !== current) {
          current = best;
          travelUntil = now + 1100;
        }
        const preset = now < travelUntil ? TRAVEL : FOLLOW;
        if (!started) {
          x.jump(tx);
          y.jump(ty);
          size.jump(s);
          started = true;
        }
        x.to(tx, preset);
        y.to(ty, preset);
        size.to(s, TRAVEL);
        shown.to(1);
        const want = (best.dataset.blobMood === "notch" ? displayMood(getNotch()) : (best.dataset.blobMood as Mood)) ?? "idle";
        if (want !== moodRef.current) {
          moodRef.current = want;
          setMood(want);
        }
      } else {
        shown.to(0);
      }
      x.step(dt, reduce);
      y.step(dt, reduce);
      size.step(dt, reduce);
      shown.step(dt, reduce);

      // Body language from motion: stretch when moving fast, lean into the direction of travel.
      const vx = reduce ? 0 : x.velocity;
      const vy = reduce ? 0 : y.velocity;
      const speed = Math.hypot(vx, vy);
      const stretch = Math.min(0.22, speed / 4200);
      const sy = 1 + stretch;
      const sx = 1 - stretch * 0.55;
      const lean = Math.max(-14, Math.min(14, vx / 70));
      const scale = size.value / BASE;

      // Look where it's going while it travels, otherwise at the pointer.
      const h = BASE * 1.2 * scale;
      const cx = x.value;
      const cy = y.value - h * 0.45;
      if (speed > 260) {
        lookRef.current.x = Math.max(-1, Math.min(1, vx / 900));
        lookRef.current.y = Math.max(-1, Math.min(1, vy / 900));
      } else {
        lookRef.current.x = Math.max(-1, Math.min(1, (live.px - cx) / 260));
        lookRef.current.y = Math.max(-1, Math.min(1, (live.py - cy) / 260 + live.scrollLook));
      }

      if (wrap.current) {
        // The box is BASE-sized; the body scales from its bottom centre, so place that point.
        wrap.current.style.transform = `translate(${x.value - BASE * 0.65}px, ${y.value - BASE * 1.2}px)`;
        wrap.current.style.opacity = String(Math.max(0, Math.min(1, shown.value)));
      }
      if (body.current) {
        body.current.style.transform = `rotate(${lean}deg) scale(${scale * sx}, ${scale * sy})`;
      }
      void t;
    });
    return () => {
      unsub();
      window.removeEventListener("scroll", mark);
      window.removeEventListener("resize", mark);
      window.removeEventListener("pointerup", mark);
    };
  }, []);

  return (
    <div ref={wrap} className="actor" aria-hidden="true">
      <div ref={body} className="actor-body">
        <BlobFigure mood={mood} size={BASE} lookRef={lookRef} />
      </div>
    </div>
  );
}
