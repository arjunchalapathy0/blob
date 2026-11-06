"use client";

import { useEffect, useRef } from "react";
import { live } from "@/lib/notch";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** VoiceLevel from AgentView: capsules that follow the microphone level, with the app's wobble. */
export function VoiceBars({ bars = 5, max = 16 }: { bars?: number; max?: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const nodes = Array.from(el.children) as HTMLElement[];
    const reduce = reducedMotion();
    return subscribe((t) => {
      nodes.forEach((n, i) => {
        const wobble = reduce ? 1 : 0.55 + 0.45 * Math.abs(Math.sin(t * 7 + i * 1.3));
        const h = Math.max(3, max * live.level * wobble);
        n.style.transform = `scaleY(${h / max})`;
      });
    });
  }, [max]);
  return (
    <span ref={ref} className="bars" style={{ height: max }} aria-hidden="true">
      {Array.from({ length: bars }, (_, i) => (
        <i key={i} style={{ height: max }} />
      ))}
    </span>
  );
}

/** The Now Playing equalizer: four bars dancing while music plays. */
export function Equalizer({ playing = true }: { playing?: boolean }) {
  const ref = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const nodes = Array.from(el.children) as HTMLElement[];
    const reduce = reducedMotion();
    return subscribe((t) => {
      nodes.forEach((n, i) => {
        const h = playing && !reduce ? 4 + 9 * Math.abs(Math.sin(t * (2.1 + i * 0.63) + i * 1.7)) : 3 + i;
        n.style.transform = `scaleY(${h / 14})`;
      });
    });
  }, [playing]);
  return (
    <span ref={ref} className="eq" aria-hidden="true">
      {[0, 1, 2, 3].map((i) => (
        <i key={i} />
      ))}
    </span>
  );
}
