"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Desktop, EMPTY_DESKTOP, type DesktopState } from "./Desktop";
import { Keycap } from "./Keycap";
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
        const match = matchRequest(text);
        const isYes = followUp && /^(yes|yeah|yep|do it|sure|ok)/i.test(text.trim());
        if (isYes && followUp) return void start({ ...followUp, spoken: text }, "typed", { typeIt: false, continuing: true });
        if (match) return void start({ ...match, spoken: text }, "typed", { typeIt: false });
        start({ id: "free", spoken: text, steps: [{ label: "Thinking", ms: 800 }], reply: OFF_SCRIPT_REPLY }, "typed", { typeIt: false });
      }),
    [start, followUp],
  );

  useEffect(() => () => abort.current?.abort(), []);

  const current = HERO_REQUESTS[selected];

  return (
    <section id="demo" className="hero" data-mood="idle" aria-labelledby="hero-title">
      <div className="wrap hero-grid">
        <div className="hero-copy">
          <h1 id="hero-title" className="display">
            <span>
              Hold <span className="h-key"><span aria-hidden="true">⌥</span><span className="sr-only">right Option</span></span>.
            </span>
            <span>Say it.</span>
            <span>Let go.</span>
          </h1>
          <p className="lead">
            Blob lives in your MacBook’s notch. Tell it what you want, out loud or typed, and it does it on your Mac:
            opens the app, finds the episode, runs the shortcut, reads the error you’re staring at. Anything it can’t
            take back, it asks about first.
          </p>

          <div className="try">
            <Keycap pressed={pressed} onDown={keyDown} onUp={keyUp} describedBy="try-copy" />
            <div className="try-copy" id="try-copy">
              <p className="small">Hold this, or the real right ⌥ if you’re on a Mac. Blob hears</p>
              <p className="quote">“{current.spoken}”</p>
            </div>
          </div>

          <div className="requests">
            <p className="small">Or watch one get typed into the notch</p>
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

        <div className="hero-stage">
          <Desktop s={desk} label="A Mac desktop where Blob carries out the request" />
        </div>
      </div>
    </section>
  );
}
