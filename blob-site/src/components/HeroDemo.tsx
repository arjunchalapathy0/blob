"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Desktop, EMPTY_DESKTOP, type DesktopState } from "./Desktop";
import { Keycap } from "./Keycap";
import { Notch } from "./Notch";
import { Cancelled, runScript } from "@/lib/agent";
import { onNotchSubmit, setAgent, setNotch, takeNotch, useNotch } from "@/lib/notch";
import { HERO_REQUESTS, OFF_SCRIPT_REPLY, matchRequest, type Script } from "@/lib/requests";
import { useScreenFit } from "@/lib/useScreenFit";

/**
 * A Mac's screen, close up, with the real notch on it. Until you touch anything Blob runs
 * through a few requests on its own; hold the key (or the real right ⌥) and it's yours.
 */
export function HeroDemo() {
  const n = useNotch();
  const [desk, setDesk] = useState<DesktopState>(EMPTY_DESKTOP);
  const [selected, setSelected] = useState(0);
  const [pressed, setPressed] = useState(false);
  const [followUp, setFollowUp] = useState<Script | null>(null);
  const abort = useRef<AbortController | null>(null);
  const release = useRef<(() => void) | null>(null);
  const [inner, fit] = useScreenFit<HTMLDivElement>(1.5);
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
        case "morning": return { ...d, shortcut: false, calendar: false, player: "hidden", music: false };
        case "error": return { ...d, terminal: "port", explained: false, player: "hidden", calendar: false, music: false };
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
      else setNotch({ open: false });
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

  const interacted = useRef(false);
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.code === "AltRight" && !e.repeat) {
        interacted.current = true;
        keyDown();
      } else if (e.code !== "AltRight" && release.current) {
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

  // Until you touch anything, Blob takes requests on its own while the screen is in view:
  // the key goes down, it listens, works, and the desktop changes.
  const area = useRef<HTMLDivElement>(null);
  const screen = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = screen.current;
    const zone = area.current;
    if (!el || !zone) return;
    let visible = false;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let keyTimer: ReturnType<typeof setTimeout> | null = null;
    let i = 0;
    const next = async () => {
      if (!visible || interacted.current) return;
      const r = HERO_REQUESTS[i % (HERO_REQUESTS.length - 1)];
      i += 1;
      setSelected(HERO_REQUESTS.indexOf(r));
      setPressed(true);
      keyTimer = setTimeout(() => setPressed(false), r.spoken.split(" ").length * 230 + 350);
      await start(r, "voice");
      if (!visible || interacted.current) return;
      timer = setTimeout(next, 1500);
    };
    const io = new IntersectionObserver(
      ([e]) => {
        const was = visible;
        visible = e.intersectionRatio >= 0.3;
        if (visible && !was && !interacted.current) timer = setTimeout(next, 900);
        if (!visible && was) {
          if (timer) clearTimeout(timer);
          if (keyTimer) clearTimeout(keyTimer);
          if (!interacted.current) {
            abort.current?.abort();
            setPressed(false);
          }
        }
      },
      { threshold: [0, 0.3, 0.6] },
    );
    io.observe(el);
    const stop = (e: Event) => {
      if (!e.isTrusted || interacted.current) return;
      interacted.current = true;
      if (timer) clearTimeout(timer);
      if (keyTimer) clearTimeout(keyTimer);
      setPressed(false);
    };
    zone.addEventListener("pointerdown", stop, true);
    zone.addEventListener("keydown", stop, true);
    return () => {
      io.disconnect();
      if (timer) clearTimeout(timer);
      if (keyTimer) clearTimeout(keyTimer);
      zone.removeEventListener("pointerdown", stop, true);
      zone.removeEventListener("keydown", stop, true);
    };
  }, [start]);

  const current = HERO_REQUESTS[selected];
  const a = n.agent;
  const hearing = !n.open && (a.phase === "listening" || a.phase === "transcribing" || a.phase === "working") && a.request.length > 0;

  return (
    <div ref={area} className="wrap hero-stage" id="demo">
      <div ref={screen} className="screen hero-screen" data-reveal="">
        <div className="screen-glow" aria-hidden="true" />
        <div className="blob-anchor" data-blob="sit" data-blob-size="104" data-blob-x="0.9" data-blob-mood="notch" />
        <div ref={inner} className="screen-inner">
          <Desktop s={desk} scale={fit.closed} compact={fit.points < 900} label="A Mac desktop where Blob carries out the request" />
          <p className="heard" data-on={hearing || undefined} data-dim={a.phase === "working" || undefined} aria-hidden="true">
            <span>You say</span>“{a.request}”
          </p>
          <Notch scale={n.open ? fit.open : fit.closed} label="The notch: hover or tap it to open, or hold right Option to talk" />
        </div>
      </div>

      <div className="controls">
        <div className="try">
          <Keycap pressed={pressed} onDown={keyDown} onUp={keyUp} describedBy="try-copy" />
          <div className="try-copy" id="try-copy">
            <p className="small">Hold the key, or right ⌥ on your keyboard. Blob hears</p>
            <p className="quote">“{current.spoken}”</p>
          </div>
        </div>
        <div className="requests">
          <p className="small">Or pick one and watch it get typed into the notch</p>
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
  );
}
