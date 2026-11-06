"use client";

import { useEffect, useRef } from "react";
import { lerpPose, pose, springProgress, stillPose, type Mood } from "@/lib/mood";
import { squirclePath } from "@/lib/notchPath";
import { reducedMotion, subscribe } from "@/lib/ticker";
import { live } from "@/lib/notch";

/**
 * The character, drawn exactly like BlobCharacter.figure: a grey continuous-corner rectangle with
 * two capsule eyes, moved only by its mood's procedural pose. One shared rAF loop drives every
 * instance; nothing re-renders per frame.
 */
type Props = {
  mood: Mood;
  size: number;
  /** "pointer": eyes follow the pointer. "notch": the notch's look (pointer + scroll). */
  look?: "pointer" | "notch" | "none";
  className?: string;
  label?: string;
  /** Pause when hidden (e.g. inside the closed notch's panel). */
  active?: boolean;
};

const BODY = squirclePath(0.09, 0.2, 1.12, 1, 0.36);

export function BlobFigure({ mood, size, look = "pointer", className, label, active = true }: Props) {
  const svg = useRef<SVGSVGElement>(null);
  const body = useRef<SVGGElement>(null);
  const eyes = useRef<SVGGElement>(null);
  const left = useRef<SVGRectElement>(null);
  const right = useRef<SVGRectElement>(null);
  const zed = useRef<SVGTextElement>(null);
  const moodRef = useRef(mood);
  const blend = useRef({ previous: mood, changedAt: -10 });
  const activeRef = useRef(active);
  activeRef.current = active;

  useEffect(() => {
    if (moodRef.current !== mood) {
      blend.current = { previous: moodRef.current, changedAt: performance.now() / 1000 };
      moodRef.current = mood;
    }
  }, [mood]);

  useEffect(() => {
    const el = svg.current;
    if (!el) return;
    let visible = true;
    // Centre in page coordinates, refreshed when the observer reports (cheap), not per frame.
    let cx = 0;
    let cy = 0;
    const io = new IntersectionObserver(
      ([entry]) => {
        visible = entry.isIntersecting;
        const r = entry.boundingClientRect;
        cx = r.left + r.width / 2 + window.scrollX;
        cy = r.top + r.height / 2 + window.scrollY;
      },
      { rootMargin: "100px", threshold: [0, 0.5, 1] },
    );
    io.observe(el);
    const fixed = !!el.closest(".notch, .menubar");
    const reduce = reducedMotion();

    const draw = (t: number) => {
      const { previous, changedAt } = blend.current;
      const current = moodRef.current;
      const p = reduce
        ? stillPose(current, t)
        : lerpPose(pose(previous, t), pose(current, t), springProgress(t - changedAt));

      let lx = 0;
      let ly = 0;
      if (look === "notch") {
        lx = live.lookX;
        ly = live.lookY + live.scrollLook;
      } else if (look === "pointer") {
        const x = cx - (fixed ? 0 : window.scrollX);
        const y = cy - (fixed ? 0 : window.scrollY);
        lx = (live.px - x) / 220;
        ly = (live.py - y) / 220 + live.scrollLook;
      }
      lx = Math.max(-1, Math.min(1, lx));
      ly = Math.max(-1, Math.min(1, ly));
      const lookX = lx * p.lookGain + p.eyeShift;
      const lookY = ly * p.lookGain;
      const rot = p.rot + lx * 3 * p.lookGain;

      body.current?.setAttribute(
        "transform",
        `translate(${p.dx} ${p.dy}) rotate(${rot} 0.65 1.2) translate(0.65 1.2) scale(${p.sx} ${p.sy}) translate(-0.65 -1.2)`,
      );
      eyes.current?.setAttribute("transform", `translate(${lookX * 0.1} ${-0.05 + lookY * 0.07})`);
      const ew = 0.13 * p.eyeScale;
      const eh = Math.max(0.035, 0.2 * p.eyeScale * p.eyeOpen);
      for (const [node, x] of [
        [left.current, 0.65 - 0.12 - ew],
        [right.current, 0.65 + 0.12],
      ] as const) {
        if (!node) continue;
        node.setAttribute("x", String(x));
        node.setAttribute("y", String(0.7 - eh / 2));
        node.setAttribute("width", String(ew));
        node.setAttribute("height", String(eh));
        node.setAttribute("rx", String(Math.min(ew, eh) / 2));
      }
      if (zed.current) {
        const f = (t % 2.4) / 2.4;
        zed.current.setAttribute("x", String(0.65 + 0.5 + 0.15 * f));
        zed.current.setAttribute("y", String(0.7 - 0.55 - 0.4 * f + 0.14));
        zed.current.setAttribute("opacity", String(p.z * (1 - f)));
      }
    };
    draw(performance.now() / 1000);
    const unsub = subscribe((t) => {
      if (visible && activeRef.current) draw(t);
    });
    return () => {
      unsub();
      io.disconnect();
    };
  }, [look]);

  return (
    <svg
      ref={svg}
      className={className ? `blob ${className}` : "blob"}
      width={size * 1.3}
      height={size * 1.2}
      viewBox="0 0 1.3 1.2"
      overflow="visible"
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      focusable="false"
    >
      <g ref={body}>
        <path d={BODY} fill="var(--blob)" />
        <g ref={eyes}>
          <rect ref={left} fill="#000" />
          <rect ref={right} fill="#000" />
        </g>
      </g>
      <text ref={zed} className="blob-z" fontSize="0.42" fontWeight="700" opacity="0">
        z
      </text>
    </svg>
  );
}
