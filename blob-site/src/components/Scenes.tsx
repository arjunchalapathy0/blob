"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Desktop, EMPTY_DESKTOP, type DesktopState } from "./Desktop";
import { Cancelled, runScript, sleep } from "@/lib/agent";
import { releaseNotch, setAgent, setNotch, takeNotch } from "@/lib/notch";
import { SCENES } from "@/lib/requests";
import { reducedMotion, subscribe } from "@/lib/ticker";
import { site } from "@/lib/site";

type Scene = {
  id: string;
  title: string;
  body: string;
  desk: Partial<DesktopState>;
};

const LIST: Scene[] = [
  {
    id: "focus",
    title: "Something to focus to.",
    body: "Say it the way you’d say it to a person. Blob opens Music, picks something, and hops along in the notch for as long as it plays.",
    desk: { terminal: "hidden" },
  },
  {
    id: "see",
    title: "It reads your screen when you ask.",
    body: "Ask why the build is failing and Blob takes one screenshot, reads it, and answers in a sentence. It looks when you ask, not before.",
    desk: { terminal: "build" },
  },
  {
    id: "shortcut",
    title: "Your shortcuts, by name.",
    body: "Anything you’ve built in Shortcuts, Blob can run. “Start my day” is a lot shorter than opening four apps.",
    desk: { terminal: "hidden" },
  },
  {
    id: "asks",
    title: "It asks before it deletes.",
    body: "Deleting, emptying the trash, sending a message, buying something: Blob says exactly what it would do and waits for a yes. It never uses sudo and never touches your passwords.",
    desk: { terminal: "hidden", downloads: true },
  },
  {
    id: "claude",
    title: "It keeps an eye on Claude Code.",
    body: "While Claude works in your terminal, the notch says so. When it stops to ask you something, Blob jumps, so you can look away in the meantime.",
    desk: { terminal: "claude" },
  },
];

export function Scenes() {
  const section = useRef<HTMLElement>(null);
  const stageWrap = useRef<HTMLDivElement>(null);
  const copies = useRef<(HTMLDivElement | null)[]>([]);
  const [index, setIndex] = useState(-1);
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

  // Scroll → which scene, and a little parallax inside it. One passive listener; no scroll-jacking.
  useEffect(() => {
    const el = section.current;
    if (!el) return;
    const reduce = reducedMotion();
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
      if (stageWrap.current && !reduce) {
        stageWrap.current.style.transform = `translateY(${(0.5 - local) * 18}px)`;
      }
    });
    return () => {
      unsub();
      io.disconnect();
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      abort.current?.abort();
    };
  }, [play]);

  // Copy changes ride the soft spring: the outgoing line moves up and away, the next one settles in.
  useEffect(() => {
    copies.current.forEach((c, i) => {
      if (!c) return;
      c.dataset.state = i === Math.max(0, index) ? "on" : i < index ? "past" : "next";
    });
  }, [index]);

  const recording = (id: string) => site.recordings.find((r) => r.scene === id);

  return (
    <section id="scenes" ref={section} className="scenes" aria-labelledby="scenes-title" style={{ height: `${(LIST.length + 1) * 100}svh` }}>
      <div className="scenes-pin">
        <div className="wrap scenes-grid">
          <div className="scenes-copy">
            <h2 id="scenes-title" className="h2">A few things it did today.</h2>
            <div className="scene-copies">
              {LIST.map((s, i) => (
                <div
                  key={s.id}
                  ref={(n) => {
                    copies.current[i] = n;
                  }}
                  className="scene-copy"
                  data-state={i === 0 ? "on" : "next"}
                  aria-hidden={i !== Math.max(0, index)}
                >
                  <span className="scene-n" aria-hidden="true">{i + 1}</span>
                  <h3 className="h3">{s.title}</h3>
                  <p className="body">{s.body}</p>
                  {recording(s.id) && (
                    <video className="recording" src={recording(s.id)!.src} poster={recording(s.id)!.poster} muted loop playsInline autoPlay preload="none" />
                  )}
                </div>
              ))}
            </div>
          </div>
          <div className="scenes-stage" ref={stageWrap}>
            <Desktop s={desk} label={index >= 0 ? `Scene ${index + 1}: ${LIST[index].title}` : "Scenes"} />
          </div>
        </div>
      </div>
      {/* For screen readers and no-JS: every scene in order. */}
      <ol className="sr-only">
        {LIST.map((s) => (
          <li key={s.id}>
            <h3>{s.title}</h3>
            <p>{s.body}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
