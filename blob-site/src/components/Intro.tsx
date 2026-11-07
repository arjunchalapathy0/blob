"use client";

import { useEffect, useRef } from "react";
import { AmbientVideo } from "./AmbientVideo";
import { notchPath } from "@/lib/notchPath";
import { Spring, Springs } from "@/lib/spring";
import { reducedMotion, subscribe } from "@/lib/ticker";

/**
 * The opening shot. A MacBook screen in a dark room; scrolling pushes the camera into the notch,
 * the notch springs open, and Blob drops out onto the headline.
 */
export function Intro() {
  const section = useRef<HTMLElement>(null);
  const screen = useRef<HTMLDivElement>(null);
  const notch = useRef<SVGPathElement>(null);
  const caption = useRef<HTMLParagraphElement>(null);
  const title = useRef<HTMLHeadingElement>(null);
  const lines = useRef<(HTMLSpanElement | null)[]>([]);
  const peekAnchor = useRef<HTMLDivElement>(null);
  const titleAnchor = useRef<HTMLDivElement>(null);
  const light = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = section.current;
    if (!el) return;
    const reduce = reducedMotion();
    const w = new Spring(185, Springs.snap);
    const h = new Spring(32, Springs.snap);
    const br = new Spring(10, Springs.snap);
    let opened = false;
    let lastP = -1;
    let p = 0;
    let onScreen = true;
    const read = () => {
      const r = el.getBoundingClientRect();
      const vh = window.innerHeight;
      onScreen = r.bottom > 0 && r.top < vh;
      p = reduce ? 1 : Math.max(0, Math.min(1, -r.top / (r.height - vh)));
    };
    read();
    let dirty = false;
    const mark = () => (dirty = true);
    window.addEventListener("scroll", mark, { passive: true });
    window.addEventListener("resize", mark, { passive: true });

    const unsub = subscribe((_, dt) => {
      if (dirty) {
        read();
        dirty = false;
      }
      if (!onScreen && w.settled) return;

      // The site's own bar stays out of the way while the screen is the whole show.
      document.documentElement.classList.toggle("in-intro", p < 0.97);

      // Camera: push into the notch.
      const zoom = smooth(p / 0.42);
      if (p !== lastP && screen.current) {
        screen.current.style.transform = `scale(${1 + zoom})`;
        lastP = p;
      }
      if (caption.current) {
        const c = 1 - smooth(p / 0.18);
        caption.current.style.opacity = String(c);
        caption.current.style.transform = `translateY(${(1 - c) * -30}px)`;
      }

      // The notch opens once the camera arrives (a spring, not scrubbed).
      const open = p > 0.38;
      if (open !== opened) {
        opened = open;
        const preset = open ? Springs.open : Springs.close;
        w.to(open ? 420 : 185, preset);
        h.to(open ? 132 : 32, preset);
        br.to(open ? 34 : 10, preset);
      }
      w.step(dt, reduce);
      h.step(dt, reduce);
      br.step(dt, reduce);
      notch.current?.setAttribute("d", notchPath(500 - w.value / 2 - 8, 0, w.value + 16, h.value, 8, br.value));

      // Blob: peeks out of the open notch, then drops onto the headline.
      peekAnchor.current?.toggleAttribute("data-blob-off", !(p > 0.4 && p < 0.58));
      titleAnchor.current?.toggleAttribute("data-blob-off", p <= 0.58);

      // The headline arrives line by line with the scroll, then holds.
      lines.current.forEach((line, i) => {
        if (!line) return;
        const v = smooth((p - 0.5 - i * 0.07) / 0.14);
        line.style.opacity = String(v);
        line.style.transform = `translateY(${(1 - v) * 60}px)`;
      });
      // The room's light comes up behind the headline as the camera arrives.
      if (light.current) light.current.style.opacity = String(smooth((p - 0.36) / 0.2));
      if (title.current) title.current.style.visibility = p > 0.45 ? "visible" : "hidden";
    });
    return () => {
      unsub();
      window.removeEventListener("scroll", mark);
      window.removeEventListener("resize", mark);
    };
  }, []);

  return (
    <section ref={section} className="intro" aria-labelledby="intro-title">
      <div className="intro-pin">
        <div className="intro-screen-wrap" aria-hidden="true">
          <div ref={screen} className="intro-screen">
            <div className="fake-menubar">
              <span className="fm-left"><b>Finder</b><span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span></span>
              <span className="fm-right">Thu 9:41</span>
            </div>
            <svg className="intro-notch" viewBox="0 0 1000 200" preserveAspectRatio="xMidYMin meet">
              <path ref={notch} d={notchPath(500 - 92.5 - 8, 0, 185 + 16, 32, 8, 10)} fill="#000" />
            </svg>
            <div ref={peekAnchor} className="blob-anchor intro-peek" data-blob="sit" data-blob-size="150" data-blob-mood="curious" data-blob-off="" />
          </div>
        </div>

        <AmbientVideo ref={light} className="intro-light" />

        <p ref={caption} className="intro-caption">
          There’s a notch at the top of your Mac.
          <br />
          <span>Something lives in it now.</span>
        </p>

        <h1 ref={title} id="intro-title" className="intro-title" style={{ visibility: "hidden" }}>
          <div ref={titleAnchor} className="blob-anchor intro-title-anchor" data-blob="sit" data-blob-size="210" data-blob-mood="happy" data-blob-off="" />
          {["Hold ⌥.", "Say it.", "Let go."].map((l, i) => (
            <span key={l} ref={(n) => { lines.current[i] = n; }} className="intro-line">
              {i === 0 ? (<>Hold <span className="h-key"><span aria-hidden="true">⌥</span><span className="sr-only">right Option</span></span>.</>) : i === 2 ? <em>Let go.</em> : l}
            </span>
          ))}
        </h1>
      </div>
    </section>
  );
}

function smooth(x: number) {
  const t = Math.max(0, Math.min(1, x));
  return t * t * (3 - 2 * t);
}
