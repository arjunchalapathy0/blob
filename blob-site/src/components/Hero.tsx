"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Desktop, EMPTY_DESKTOP, type DesktopState } from "./Desktop";
import { Keycap } from "./Keycap";
import { Eyebrow } from "./Chrome";
import { Notch } from "./Notch";
import { useNotchScale } from "@/lib/useNotchScale";
import { Cancelled, runScript } from "@/lib/agent";
import { onNotchSubmit, setAgent, setNotch, takeNotch } from "@/lib/notch";
import { HERO_REQUESTS, OFF_SCRIPT_REPLY, matchRequest, type Script } from "@/lib/requests";

export function Hero() {
  const [desk, setDesk] = useState<DesktopState>(EMPTY_DESKTOP);
  const [selected, setSelected] = useState(0);
  const [pressed, setPressed] = useState(false);
  const [followUp, setFollowUp] = useState<Script | null>(null);
  const abort = useRef<AbortController | null>(null);
  const release = useRef<(() => void) | null>(null);
  const notchScale = useNotchScale(1.68, 0.94);
  const selectedRef = useRef(0);
  selectedRef.current = selected;

  const outcome = useCallback((o: string) => {
    setDesk((d) => {
      switch (o) {
        case "player-open": return { ...d, player: "open", music: false };
        case "player-play": return { ...d, player: "playing" };
        case "music-play": return { ...d, music: true, musicTitle: "Calm", player: "hidden" };
        case "shortcut": return { ...d, shortcut: true, calendar: true };
        case "scan": return { ...d, scan: d.scan + 1, terminal: "port" };
        case "explain": return { ...d, explained: true };
        case "trash-empty": return { ...d, trash: "empty" };
        default: return d;
      }
    });
  }, []);

  /** Clears what this request is about to change, so each run reads cleanly. */
  const prepare = (id: string) => {
    setDesk((d) => {
      switch (id) {
        case "anime": return { ...d, player: "hidden", music: false, shortcut: false, calendar: false, terminal: "hidden" };
        case "calm": return { ...d, player: "hidden", shortcut: false };
        case "morning": return { ...d, shortcut: false, calendar: false, player: "hidden" };
        case "error": return { ...d, terminal: "port", explained: false, player: "hidden", calendar: false };
        case "trash": return { ...d, trash: "full", trashBadge: true };
        default: return d;
      }
    });
  };

  const start = useCallback(
    async (script: Script, mode: "voice" | "typed", opts: { released?: Promise<number>; continuing?: boolean; typeIt?: boolean } = {}) => {
      abort.current?.abort();
      const ctrl = new AbortController();
      abort.current = ctrl;
      takeNotch("hero", () => ctrl.abort());
      setFollowUp(null);
      if (mode === "typed") setNotch({ holdUntil: performance.now() + 60_000 });
      prepare(script.id);
      try {
        const result = await runScript(script, {
          signal: ctrl.signal,
          mode,
          released: opts.released,
          onOutcome: outcome,
          continuing: opts.continuing,
          skipTyping: opts.typeIt === false,
        });
        if (result === "done") {
          if (script.followUp) setFollowUp(script.followUp.script);
          if (mode === "typed") setNotch({ holdUntil: performance.now() + 6000 });
          if (script.id === "morning") setTimeout(() => setDesk((d) => ({ ...d, shortcut: false })), 2500);
        }
      } catch (e) {
        if (!(e instanceof Cancelled)) throw e;
      }
    },
    [outcome],
  );

  // Voice: hold the keycap or the real right ⌥.
  const keyDown = useCallback(() => {
    setPressed(true);
    const released = new Promise<number>((resolve) => {
      release.current = () => resolve(performance.now());
    });
    start(HERO_REQUESTS[selectedRef.current], "voice", { released });
  }, [start]);
  const keyUp = useCallback(() => {
    setPressed(false);
    release.current?.();
    release.current = null;
  }, []);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.code === "AltRight" && !e.repeat) keyDown();
      else if (e.code !== "AltRight" && release.current) {
        // ⌥ + another key is a shortcut, not a voice request (VoiceKey.otherKeyPressed).
        abort.current?.abort();
        keyUp();
        setNotch({ wing: { kind: "none" } });
        setAgent({ phase: "idle", request: "" });
      }
    };
    const up = (e: KeyboardEvent) => {
      if (e.code === "AltRight") keyUp();
    };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
    };
  }, [keyDown, keyUp]);

  // Anything typed into the notch.
  useEffect(
    () =>
      onNotchSubmit((text) => {
        interacted.current = true;
        const match = matchRequest(text);
        const isYes = followUp && /^(yes|yeah|yep|do it|sure|ok)/i.test(text.trim());
        if (isYes && followUp) return void start({ ...followUp, spoken: text }, "typed", { typeIt: false, continuing: true });
        if (match) return void start({ ...match, spoken: text }, "typed", { typeIt: false });
        start({ id: "free", spoken: text, steps: [{ label: "Thinking", ms: 800 }], reply: OFF_SCRIPT_REPLY }, "typed", { typeIt: false });
      }),
    [start, followUp],
  );

  useEffect(() => () => abort.current?.abort(), []);

  // Until you touch anything, Blob runs through the requests on its own while the demo is on screen.
  const section = useRef<HTMLElement>(null);
  const interacted = useRef(false);
  useEffect(() => {
    const el = section.current;
    if (!el) return;
    let visible = false;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let i = 0;
    const next = async () => {
      if (!visible || interacted.current) return;
      const r = HERO_REQUESTS[i % (HERO_REQUESTS.length - 1)];
      i += 1;
      setSelected(HERO_REQUESTS.indexOf(r));
      await start(r, "typed");
      if (!visible || interacted.current) return;
      setNotch({ holdUntil: 0 });
      timer = setTimeout(() => {
        setNotch({ open: false });
        timer = setTimeout(next, 1400);
      }, 2600);
    };
    const io = new IntersectionObserver(
      ([e]) => {
        const was = visible;
        visible = e.intersectionRatio > 0.45;
        if (visible && !was && !interacted.current) timer = setTimeout(next, 700);
        if (!visible && was) {
          if (timer) clearTimeout(timer);
          if (!interacted.current) abort.current?.abort();
        }
      },
      { threshold: [0, 0.45, 0.6] },
    );
    io.observe(el);
    const stop = (e: Event) => {
      if (e.isTrusted) interacted.current = true;
    };
    el.addEventListener("pointerdown", stop, true);
    el.addEventListener("keydown", stop, true);
    window.addEventListener("keydown", (e) => e.code === "AltRight" && stop(e));
    return () => {
      io.disconnect();
      if (timer) clearTimeout(timer);
      el.removeEventListener("pointerdown", stop, true);
      el.removeEventListener("keydown", stop, true);
    };
  }, [start]);

  const current = HERO_REQUESTS[selected];

  return (
    <section id="demo" ref={section} className="demo" aria-labelledby="demo-title">
      <div className="wrap">
        <div className="demo-head">
          <div>
            <Eyebrow n="01">Try it</Eyebrow>
            <h2 id="demo-title" className="h2" data-reveal="">Go on, <em>try it.</em></h2>
          </div>
          <p className="body" data-reveal="" style={{ "--d": 2 } as React.CSSProperties}>
            This is the real notch, at real proportions, blown up. Hold the key, or right ⌥ on your keyboard, and
            Blob hears you. Or pick something and watch it get typed in.
          </p>
        </div>

        <div className="mac" data-reveal="">
          <div className="blob-anchor" data-blob="sit" data-blob-size="96" data-blob-x="0.86" data-blob-mood="notch" />
          <div className="mac-screen">
            <Notch scale={notchScale} label="The notch: hover or tap it to open, or hold right Option to talk" />
            <Desktop s={desk} label="A Mac desktop where Blob carries out the request" />
          </div>
        </div>

        <div className="controls">
          <div className="try">
            <Keycap pressed={pressed} onDown={keyDown} onUp={keyUp} describedBy="try-copy" />
            <div className="try-copy" id="try-copy">
              <p className="small">Hold to talk. Blob hears</p>
              <p className="quote">“{current.spoken}”</p>
            </div>
          </div>
          <div className="requests">
            <p className="small">Or have it typed into the notch</p>
            <ul>
              {HERO_REQUESTS.map((r, i) => (
                <li key={r.id}>
                  <button
                    type="button"
                    className={i === selected ? "request on" : "request"}
                    aria-pressed={i === selected}
                    onClick={() => {
                      setSelected(i);
                      start(r, "typed");
                    }}
                  >
                    {r.spoken}
                  </button>
                </li>
              ))}
              {followUp && (
                <li>
                  <button type="button" className="request follow" onClick={() => start(followUp, "typed", { continuing: true })}>
                    {followUp.spoken}
                  </button>
                </li>
              )}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
