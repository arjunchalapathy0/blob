"use client";

import { useEffect, useRef } from "react";
import { Spring, Springs } from "@/lib/spring";
import { reducedMotion, subscribe } from "@/lib/ticker";

/** The right ⌥ key. Press and hold with the pointer, Space/Enter, or the real key. */
export function Keycap({
  pressed, onDown, onUp, describedBy,
}: { pressed: boolean; onDown: () => void; onUp: () => void; describedBy?: string }) {
  const cap = useRef<HTMLSpanElement>(null);
  const pressedRef = useRef(pressed);
  pressedRef.current = pressed;
  const holding = useRef(false);

  useEffect(() => {
    const reduce = reducedMotion();
    const sp = new Spring(0, Springs.snap);
    return subscribe((_, dt) => {
      sp.to(pressedRef.current ? 1 : 0, pressedRef.current ? Springs.snap : Springs.wobble);
      const v = sp.step(dt, reduce);
      if (cap.current) cap.current.style.transform = `translateY(${v * 3}px)`;
    });
  }, []);

  const down = () => {
    if (holding.current) return;
    holding.current = true;
    onDown();
  };
  const up = () => {
    if (!holding.current) return;
    holding.current = false;
    onUp();
  };

  return (
    <button
      type="button"
      className={pressed ? "keycap is-down" : "keycap"}
      aria-describedby={describedBy}
      aria-pressed={pressed}
      onPointerDown={(e) => {
        e.currentTarget.setPointerCapture(e.pointerId);
        down();
      }}
      onPointerUp={up}
      onPointerCancel={up}
      onKeyDown={(e) => {
        if ((e.key === " " || e.key === "Enter") && !e.repeat) {
          e.preventDefault();
          down();
        }
      }}
      onKeyUp={(e) => {
        if (e.key === " " || e.key === "Enter") {
          e.preventDefault();
          up();
        }
      }}
      onContextMenu={(e) => e.preventDefault()}
    >
      <span className="sr-only">Hold to talk,</span>
      <span className="keycap-well">
        <span ref={cap} className="keycap-cap">
          <span className="k-sym" aria-hidden="true">⌥</span>
          <span className="k-word">option</span>
        </span>
      </span>
    </button>
  );
}
