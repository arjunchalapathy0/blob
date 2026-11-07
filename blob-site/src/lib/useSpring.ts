"use client";

import { useEffect, useRef } from "react";
import { Spring, Springs, type SpringPreset } from "./spring";
import { reducedMotion, subscribe } from "./ticker";

/**
 * Drives an element in and out with one of the app's springs, writing only transform and opacity.
 * `amount` is 0 (gone) … 1 (in place); values in between are allowed (e.g. scroll progress).
 */
export function useSpringIn<T extends HTMLElement>(
  amount: number,
  { preset = Springs.open, y = 28, scale = 0.96, x = 0 }: { preset?: SpringPreset; y?: number; scale?: number; x?: number } = {},
) {
  const ref = useRef<T>(null);
  const target = useRef(amount);
  target.current = amount;
  useEffect(() => {
    const reduce = reducedMotion();
    const sp = new Spring(target.current, preset);
    let last = -1;
    return subscribe((_, dt) => {
      sp.to(target.current, preset);
      const v = sp.step(dt, reduce);
      if (Math.abs(v - last) < 0.0005) return;
      last = v;
      const el = ref.current;
      if (!el) return;
      el.style.opacity = String(Math.max(0, Math.min(1, v)));
      el.style.transform = `translate(${(1 - v) * x}px, ${(1 - v) * y}px) scale(${scale + (1 - scale) * v})`;
      el.style.visibility = v < 0.01 ? "hidden" : "visible";
    });
  }, [preset, y, scale, x]);
  return ref;
}
