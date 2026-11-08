"use client";

import { useEffect, useState } from "react";

/** Scale for an embedded notch: `desktop` on wide screens, shrinking so the open notch always fits. */
export function useNotchScale(desktop: number, fraction = 0.92) {
  const [scale, setScale] = useState(desktop);
  useEffect(() => {
    const fit = () => {
      const vw = window.innerWidth;
      const stage = vw < 900 ? (vw - 32) * 0.96 : Math.min(vw - 32, 1280) * fraction;
      setScale(Math.min(desktop, stage / 748));
    };
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, [desktop, fraction]);
  return scale;
}
