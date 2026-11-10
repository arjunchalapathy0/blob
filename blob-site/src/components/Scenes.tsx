"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Desktop, EMPTY_DESKTOP, type DesktopState } from "./Desktop";
import { Cancelled, runScript, sleep } from "@/lib/agent";
import { releaseNotch, setAgent, setNotch, takeNotch, useNotch } from "@/lib/notch";
import { SCENES } from "@/lib/requests";
import { reducedMotion, subscribe } from "@/lib/ticker";
import { site } from "@/lib/site";
import { Eyebrow } from "./Chrome";
import { Notch } from "./Notch";
import { useScreenFit } from "@/lib/useScreenFit";

type Scene = {
  id: string;
  title: string;
  body: string;
  desk: Partial<DesktopState>;
  /** How Blob, perched on the screen, feels about it. */
  mood: string;
};

const LIST: Scene[] = [
  {
    id: "focus",
    title: "Something to focus to.",
    body: "Say it the way you’d say it to a person. Blob opens Music, picks something, and hops along in the notch for as long as it plays.",
    desk: { terminal: "hidden" },
    mood: "happy",
  },
  {
    id: "see",
    title: "It reads your screen when you ask.",
    body: "Ask why the build is failing and Blob takes one screenshot, reads it, and answers in a sentence. It looks when you ask, not before.",
    desk: { terminal: "build" },
    mood: "busy",
  },
  {
    id: "shortcut",
    title: "Your shortcuts, by name.",
    body: "Anything you’ve built in Shortcuts, Blob can run. “Start my day” is a lot shorter than opening four apps.",
    desk: { terminal: "hidden" },
    mood: "busy",
  },
  {
    id: "asks",
    title: "It asks before it deletes.",
    body: "Deleting, emptying the trash, sending a message, buying something: Blob says exactly what it would do and waits for a yes. It never uses sudo and never touches your passwords.",
    desk: { terminal: "hidden", downloads: true },
    mood: "curious",
  },
  {
    id: "claude",
    title: "It keeps an eye on Claude Code.",
    body: "While Claude works in your terminal, the notch says so. When it stops to ask you something, Blob jumps, so you can look away in the meantime.",
    desk: { terminal: "claude" },
    mood: "notch",
  },
];

export function Scenes() {
  const n = useNotch();
  const section = useRef<HTMLElement>(null);
  const bars = useRef<(HTMLSpanElement | null)[]>([]);
  const [index, setIndex] = useState(-1);
  const [inner, fit] = useScreenFit<HTMLDivElement>(1);
  const [desk, setDesk] = useState<DesktopState>({ ...EMPTY_DESKTOP, terminal: "hidden", trashBadge: false });
  const abort = useRef<AbortController | null>(null);
  const indexRef = useRef(-1);

  const outcome = useCallback((o: string) => {
    setDesk((d) => {
      switch (o) {
        case "music-play": return { ...d, music: true, musicTitle: "Focus" };
        case "scan": return { ...d, scan: d.scan + 1 };
        case "explain": return { ...d, explained: true };
        case "shortcut": return { ...d, shortcut: true, calendar: true };
        case "ask": return { ...d, asked: true };
        default: return d;
      }
    });
  }, []);

  const play = useCallback(
    async (i: number) => {
      abort.current?.abort();
      const ctrl = new AbortController();
      abort.current = ctrl;
      takeNotch("scenes", () => ctrl.abort());
      setNotch({ open: false, wing: { kind: "none" }, mood: "idle" });
      setAgent({ phase: "idle", request: "", steps: [], reply: "" });
      const scene = LIST[i];
      setDesk({ ...EMPTY_DESKTOP, terminal: "hidden", trashBadge: false, ...scene.desk });
      try {
        await sleep(350, ctrl.signal);
        if (scene.id === "claude") {
          // Claude Code status comes from Blob's hooks, not from a request.
          setNotch({ wing: { kind: "claude", state: "working" } });
          while (!ctrl.signal.aborted) {
            await sleep(2600, ctrl.signal);
            setNotch({ wing: { kind: "claude", state: "waiting" } });
            await sleep(3200, ctrl.signal);
            setNotch({ wing: { kind: "claude", state: "working" } });
          }
          return;
        }
        const script = SCENES[scene.id as keyof typeof SCENES];
        await runScript(script, { signal: ctrl.signal, mode: "voice", onOutcome: outcome });
      } catch (e) {
        if (!(e instanceof Cancelled)) throw e;
      }
    },
    [outcome],
  );

  // Scroll picks the scene and fills its progress line. One passive listener; no scroll-jacking.
  useEffect(() => {
    const el = section.current;
    if (!el) return;
    let inView = false;
    const io = new IntersectionObserver(([e]) => {
      inView = e.isIntersecting;
      if (!inView && indexRef.current !== -1) {
        abort.current?.abort();
        releaseNotch("scenes");
        indexRef.current = -1;
        setIndex(-1);
      }
    });
    io.observe(el);

    let pending = true;
    const onScroll = () => (pending = true);
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });

    const unsub = subscribe(() => {
      if (!pending || !inView) return;
      pending = false;
      const r = el.getBoundingClientRect();
      const vh = window.innerHeight;
      const total = r.height - vh;
      const p = Math.max(0, Math.min(0.9999, -r.top / total));
      const active = r.top <= vh * 0.35 && r.bottom >= vh * 0.6;
      const i = active ? Math.min(LIST.length - 1, Math.floor(p * LIST.length)) : -1;
      if (i !== indexRef.current) {
        indexRef.current = i;
        setIndex(i);
        if (i >= 0) play(i);
        else {
          abort.current?.abort();
          releaseNotch("scenes");
        }
      }
      const local = p * LIST.length - Math.max(0, i);
      bars.current.forEach((b, k) => {
        if (b) b.style.transform = `scaleX(${k === i ? local.toFixed(3) : 0})`;
      });
    });
    return () => {
      unsub();
      io.disconnect();
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      abort.current?.abort();
    };
  }, [play]);

  /** Clicking a title scrolls to where that scene plays. */
  const go = (i: number) => {
    const el = section.current;
    if (!el) return;
    const total = el.offsetHeight - window.innerHeight;
    const top = el.getBoundingClientRect().top + window.scrollY;
    window.scrollTo({ top: top + ((i + 0.15) / LIST.length) * total, behavior: reducedMotion() ? "auto" : "smooth" });
  };

  const recording = (id: string) => site.recordings.find((r) => r.scene === id);
  const shown = Math.max(0, index);
  const a = n.agent;
  const hearing = index >= 0 && (a.phase === "listening" || a.phase === "transcribing" || a.phase === "working") && a.request.length > 0;

  return (
    <section id="scenes" ref={section} className="scenes" aria-labelledby="scenes-title" style={{ height: `${LIST.length * 80 + 100}svh` }}>
      <div className="scenes-pin">
        <div className="wrap scenes-grid">
          <div className="scenes-copy">
            <Eyebrow n="01">A day with Blob</Eyebrow>
            <h2 id="scenes-title" className="h2">A few things it <em>did today.</em></h2>
            <ol className="scene-list">
              {LIST.map((s, i) => (
                <li key={s.id} className="scene" data-on={i === shown || undefined}>
                  <span ref={(node) => { bars.current[i] = node; }} className="scene-bar" aria-hidden="true" />
                  <button type="button" className="scene-head h3" aria-expanded={i === shown} onClick={() => go(i)}>
                    <span className="scene-n" aria-hidden="true">{String(i + 1).padStart(2, "0")}</span>
                    <span>{s.title}</span>
                  </button>
                  <div className="scene-body">
                    <div>
                      <p>{s.body}</p>
                      {recording(s.id) && i === shown && (
                        <video className="recording" src={recording(s.id)!.src} poster={recording(s.id)!.poster} muted loop playsInline autoPlay preload="none" />
                      )}
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          </div>
          <div className="scenes-stage">
            <div className="screen">
              <div className="screen-glow" aria-hidden="true" />
              <div
                className="blob-anchor"
                data-blob="sit"
                data-blob-size="96"
                data-blob-x="0.14"
                data-blob-mood={LIST[shown].mood}
                data-blob-priority="200"
              />
              <div ref={inner} className="screen-inner">
                <Desktop s={desk} scale={fit.closed} compact={fit.points < 900} label={index >= 0 ? `Scene ${index + 1}: ${LIST[index].title}` : "Scenes"} />
                <p className="heard" data-on={hearing || undefined} data-dim={a.phase === "working" || undefined} aria-hidden="true">
                  <span>You say</span>“{a.request}”
                </p>
                <Notch scale={n.open ? fit.open : fit.closed} label="The notch during this scene" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
