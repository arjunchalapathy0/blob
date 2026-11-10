"use client";

import { useEffect, useRef, useState } from "react";

/** Widest the closed notch gets (with its longest wings), and the open panel, in Mac points. */
const CLOSED_MAX = 520;
const OPEN_MAX = 748;

/**
 * How big to draw the notch and desktop inside a screen element.
 * `closed` makes the closed notch (and its wings) as large as `max` allows; `open` is smaller
 * when the open panel wouldn't fit, so on a phone the notch zooms out as it opens.
 * `points` is how many Mac points wide the screen is at the closed scale.
 */
export function useScreenFit<T extends HTMLElement>(max: number) {
  const ref = useRef<T>(null);
  const [fit, setFit] = useState({ closed: max, open: max, points: 1200 });
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = (width: number) => {
      if (!width) return;
      const closed = Math.min(max, width / CLOSED_MAX);
      const open = Math.min(closed, (width * 0.97) / OPEN_MAX);
      const points = width / closed;
      setFit((f) =>
        Math.abs(f.closed - closed) < 0.005 && Math.abs(f.open - open) < 0.005 && Math.abs(f.points - points) < 4 ? f : { closed, open, points },
      );
    };
    measure(el.clientWidth);
    const ro = new ResizeObserver(([e]) => measure(e.contentRect.width));
    ro.observe(el);
    return () => ro.disconnect();
  }, [max]);
  return [ref, fit] as const;
}
