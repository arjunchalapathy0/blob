"use client";

import { useEffect, useRef } from "react";
import { BlobFigure } from "./BlobFigure";
import { Equalizer, VoiceBars } from "./Bars";
import { Glyph } from "./Glyph";
import { NOTCH, notchPath } from "@/lib/notchPath";
import { Spring, Springs } from "@/lib/spring";
import { reducedMotion, subscribe } from "@/lib/ticker";
import {
  getNotch, live, resetAgent, setAgent, setNotch, stopNotch, submitFromNotch, useNotch,
  type NotchState, type Wing,
} from "@/lib/notch";
import type { Mood } from "@/lib/mood";

/** LiveActivity.wingWidth */
function wingWidth(w: Wing): number {
  switch (w.kind) {
    case "none": return 0;
    case "listening":
    case "transcribing": return 66;
    case "working": return 150;
    case "notice": return 104;
    case "volume": return 70;
    case "timerDone": return 76;
    case "claude": return 86;
    case "timer": return 60;
    case "event": return 72;
    case "music": return 40;
  }
}

/** NotchViewModel.resolveMood, for what the page can know. */
export function displayMood(s: NotchState): Mood {
  if (s.agent.phase === "listening") return "curious";
  if (s.agent.phase === "transcribing" || s.agent.phase === "working") return "busy";
  if (s.wing.kind === "timerDone" || (s.wing.kind === "claude" && s.wing.state === "waiting")) return "alarmed";
  if (s.wing.kind === "claude" && s.wing.state === "working") return "busy";
  if (s.mood === "alarmed" || s.mood === "busy" || s.mood === "happy") return s.mood;
  if (s.wing.kind === "music") return "happy";
  if (s.peek || s.open) return "curious";
  return s.mood;
}

const MAX_W = NOTCH.openWidth + 28;
const MAX_H = NOTCH.height + NOTCH.openExtra + 4;

/**
 * The notch, drawn at `scale` inside its stage (its box is absolutely positioned at the top centre of
 * the nearest positioned parent). Several stages can show it; they all share one state, and only
 * the ones on screen do any work.
 */
export function Notch({ scale = 1, label = "Blob's notch" }: { scale?: number; label?: string }) {
  const s = useNotch();
  const root = useRef<HTMLDivElement>(null);
  const shape = useRef<HTMLDivElement>(null);
  const leftWing = useRef<HTMLDivElement>(null);
  const rightWing = useRef<HTMLDivElement>(null);
  const peek = useRef<HTMLDivElement>(null);
  const panel = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const stateRef = useRef(s);
  stateRef.current = s;
  const touchRef = useRef(false);
  const scaleRef = useRef(scale);
  scaleRef.current = scale;

  const ww = wingWidth(s.wing);

  useEffect(() => {
    const reduce = reducedMotion();
    const w = new Spring(NOTCH.width);
    const h = new Spring(NOTCH.height);
    const tr = new Spring(6);
    const br = new Spring(10);
    const wingsIn = new Spring(0);
    const peekIn = new Spring(0);
    const panelIn = new Spring(0);
    let lastKey = "";
    let wasOpen = false;
    let hoverSince = 0;
    let leftAt = 0;
    const cx = MAX_W / 2;
    let rightWidth = 0;
    let lastPath = "";
    let lastRight = "";
    let lastPeek = "";
    let lastPanel = "";
    let visible = false;
    let rect = { left: 0, top: 0 };
    let rectDirty = true;
    const dirty = () => (rectDirty = true);
    window.addEventListener("resize", dirty, { passive: true });
    window.addEventListener("scroll", dirty, { passive: true });
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
      rectDirty = true;
    });
    if (root.current) io.observe(root.current);
    const ro = new ResizeObserver(([e]) => (rightWidth = e.contentRect.width));
    if (rightWing.current) ro.observe(rightWing.current);

    const unsub = subscribe((_t, dt) => {
      const st = stateRef.current;
      const el = root.current;
      if (!el || !visible) return;
      const S = scaleRef.current;
      if (rectDirty) {
        const r = el.getBoundingClientRect();
        rect = { left: r.left, top: r.top };
        rectDirty = false;
      }
      // Pointer in the notch's own (unscaled) coordinates.
      const lx = (live.px - rect.left) / S;
      const ly = (live.py - rect.top) / S;

      // Hover: peek after 60 ms, open after another 300 ms (NotchViewModel.scheduleHover).
      const bw = w.value + 2 * tr.value;
      const margin = st.open ? 12 : st.peek ? 4 : 6;
      const inside = Math.abs(lx - cx) <= bw / 2 + margin && ly >= -4 && ly <= h.value + margin;
      const now = performance.now();
      if (!touchRef.current) {
        if (inside) {
          leftAt = 0;
          if (!hoverSince) hoverSince = now;
          if (!st.open && !st.peek && now - hoverSince > 60) setNotch({ peek: true });
          if (!st.open && now - hoverSince > 360) setNotch({ open: true, peek: false });
        } else if (hoverSince || st.peek || st.open) {
          hoverSince = 0;
          const busy = st.agent.phase === "working" || st.agent.phase === "listening" || st.agent.phase === "transcribing";
          const typing = document.activeElement === input.current && st.agent.draft.length > 0;
          if (st.peek) setNotch({ peek: false });
          if (st.open && !busy && !typing && now > st.holdUntil) {
            if (!leftAt) leftAt = now;
            if (now - leftAt > 320) {
              setNotch({ open: false });
              leftAt = 0;
            }
          } else {
            leftAt = 0;
          }
        }
      }
      el.classList.toggle("is-hover", inside && !st.open);

      // Targets (NotchViewModel.bodySize / topRadius / bottomRadius).
      const wing = wingWidth(st.wing);
      const closedW = NOTCH.width + 2 * wing;
      let tw = closedW, th = NOTCH.height, ttr = 6, tbr = st.wing.kind === "none" ? 10 : 12;
      if (st.open) {
        tw = NOTCH.openWidth;
        th = NOTCH.height + NOTCH.openExtra;
        ttr = 14;
        tbr = 30;
      } else if (st.peek) {
        tw = Math.max(closedW, NOTCH.width + 28);
        th = NOTCH.height + 30;
        tbr = 18;
      }
      const preset = st.open ? Springs.open : wasOpen ? Springs.close : Springs.snap;
      if (st.open !== wasOpen) wasOpen = st.open;
      w.to(tw, preset);
      h.to(th, preset);
      tr.to(ttr, preset);
      br.to(tbr, preset);
      [w, h, tr, br].forEach((sp) => sp.step(dt, reduce));

      const key = st.wing.kind + (st.wing.kind === "notice" ? st.wing.text : "");
      if (key !== lastKey) {
        lastKey = key;
        lastRight = "";
        if (!reduce) wingsIn.jump(0);
      }
      wingsIn.to(st.wing.kind !== "none" && !st.open ? 1 : 0, Springs.snap);
      peekIn.to(st.peek && !st.open ? 1 : 0, Springs.snap);
      panelIn.to(st.open ? 1 : 0, st.open ? Springs.soft : Springs.close);
      [wingsIn, peekIn, panelIn].forEach((sp) => sp.step(dt, reduce));

      const fw = w.value + 2 * tr.value;
      const x0 = cx - fw / 2;
      const path = notchPath(x0, 0, fw, h.value, tr.value, br.value);
      if (path !== lastPath && shape.current) {
        shape.current.style.clipPath = `path("${path}")`;
        lastPath = path;
      }
      const bodyLeft = x0 + tr.value;
      const bodyRight = x0 + fw - tr.value;
      const wingOpacity = Math.max(0, wingsIn.value).toFixed(3);
      const right = `${(bodyLeft + 10).toFixed(1)}|${(bodyRight - 10 - rightWidth).toFixed(1)}|${wingOpacity}`;
      if (right !== lastRight) {
        lastRight = right;
        if (leftWing.current) {
          leftWing.current.style.transform = `translateX(${bodyLeft + 10}px)`;
          leftWing.current.style.opacity = wingOpacity;
        }
        if (rightWing.current) {
          rightWing.current.style.transform = `translateX(${bodyRight - 10 - rightWidth}px)`;
          rightWing.current.style.opacity = wingOpacity;
        }
      }
      const pk = peekIn.value.toFixed(3);
      if (pk !== lastPeek && peek.current) {
        lastPeek = pk;
        peek.current.style.opacity = String(Math.max(0, peekIn.value));
        peek.current.style.transform = `translate(${cx - 13}px, ${NOTCH.height + 1 - (1 - peekIn.value) * 14}px)`;
      }
      const pn = `${panelIn.value.toFixed(3)}|${st.open}`;
      if (pn !== lastPanel && panel.current) {
        lastPanel = pn;
        panel.current.style.opacity = String(Math.max(0, panelIn.value));
        panel.current.style.transform = `translateX(${cx - NOTCH.openWidth / 2}px) scale(${0.96 + 0.04 * Math.min(1, panelIn.value)})`;
        panel.current.style.visibility = panelIn.value < 0.02 && !st.open ? "hidden" : "visible";
      }

      // Where Blob looks: at the pointer, relative to where it sits.
      const bx = st.open ? cx - NOTCH.openWidth / 2 + 30 : cx;
      const by = st.open ? NOTCH.height / 2 : NOTCH.height + 14;
      live.lookX = Math.max(-1, Math.min(1, ((lx - bx) * S) / 220));
      live.lookY = Math.max(-1, Math.min(1, ((ly - by) * S) / 160));
    });
    return () => {
      unsub();
      ro.disconnect();
      io.disconnect();
      window.removeEventListener("resize", dirty);
      window.removeEventListener("scroll", dirty);
    };
  }, []);

  // Touch: tap the notch to open, tap elsewhere to close. Pointer position for everything.
  useEffect(() => {
    touchRef.current = window.matchMedia("(pointer: coarse)").matches;
    const move = (e: PointerEvent) => {
      live.px = e.clientX;
      live.py = e.clientY;
      if (e.pointerType === "mouse") touchRef.current = false;
    };
    const down = (e: PointerEvent) => {
      const el = root.current;
      if (!el || e.pointerType === "mouse") return;
      const st = getNotch();
      const r = el.getBoundingClientRect();
      const S = scaleRef.current;
      const lx = (e.clientX - r.left) / S;
      const ly = (e.clientY - r.top) / S;
      const onNotch = Math.abs(lx - MAX_W / 2) < (st.open ? NOTCH.openWidth / 2 : 120) && ly >= 0 && ly < (st.open ? 220 : 48);
      const insidePanel = panel.current?.contains(e.target as Node);
      if (!st.open && onNotch) setNotch({ open: true, peek: false });
      else if (st.open && !insidePanel && !onNotch && Math.abs(e.clientY - r.top) < 600 && st.agent.phase !== "working") setNotch({ open: false });
    };
    const key = (e: KeyboardEvent) => {
      if (e.key === "Escape" && getNotch().open) setNotch({ open: false, holdUntil: 0 });
    };
    window.addEventListener("pointermove", move, { passive: true });
    window.addEventListener("pointerdown", down, { passive: true });
    window.addEventListener("keydown", key);
    const openFocus = () => {
      if (!root.current) return;
      const r = root.current.getBoundingClientRect();
      if (r.bottom < 0 || r.top > window.innerHeight) return;
      setNotch({ open: true, holdUntil: performance.now() + 8000 });
      requestAnimationFrame(() => input.current?.focus());
    };
    window.addEventListener("blob:focus-notch", openFocus);
    return () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerdown", down);
      window.removeEventListener("keydown", key);
      window.removeEventListener("blob:focus-notch", openFocus);
    };
  }, []);

  const mood = displayMood(s);

  return (
    <div
      ref={root}
      className="notch"
      style={{ width: MAX_W, height: MAX_H, transform: `translateX(-50%) scale(${scale})` }}
      role="group"
      aria-label={label}
    >
      <div ref={shape} className="notch-shape">
        <div ref={leftWing} className="wing wing-left" style={{ width: Math.max(0, ww - 10), opacity: 0 }}>
          <WingSide wing={s.wing} side="left" mood={mood} />
        </div>
        <div ref={rightWing} className="wing wing-right" style={{ opacity: 0 }}>
          <WingSide wing={s.wing} side="right" mood={mood} />
        </div>
        <div ref={peek} className="notch-peek" aria-hidden="true">
          <BlobFigure mood={mood} size={16} look="notch" active={s.peek && !s.open} />
        </div>
        <div ref={panel} className="panel" style={{ width: NOTCH.openWidth, height: NOTCH.height + NOTCH.openExtra }} inert={!s.open}>
          <Panel s={s} mood={mood} input={input} />
        </div>
      </div>
      <p className="sr-only" aria-live="polite">
        {s.agent.phase === "done" ? `Blob: ${s.agent.reply}` : ""}
      </p>
    </div>
  );
}

function WingSide({ wing, side, mood }: { wing: Wing; side: "left" | "right"; mood: Mood }) {
  const L = side === "left";
  switch (wing.kind) {
    case "none":
      return null;
    case "listening":
      return L ? <Glyph name="mic" size={14} /> : <VoiceBars />;
    case "transcribing":
      return L ? <BlobFigure mood="busy" size={13} look="none" /> : <span className="wing-text">…</span>;
    case "working":
      return L ? <BlobFigure mood="busy" size={13} look="none" /> : <span className="wing-text dim step">{wing.step}</span>;
    case "notice":
      return L ? <Glyph name={wing.icon === "check" ? "checkCircle" : wing.icon} size={14} /> : <span className="wing-text small">{wing.text}</span>;
    case "music":
      return L ? <span className="art" /> : <Equalizer />;
    case "timer":
      return L ? <Glyph name="timer" size={14} /> : <span className="wing-text digits">{wing.text}</span>;
    case "timerDone":
      return L ? <BlobFigure mood="alarmed" size={13} look="none" /> : <span className="wing-text">Time’s up</span>;
    case "claude":
      return L ? <BlobFigure mood={mood} size={13} look="none" /> : (
        <span className={wing.state === "waiting" ? "wing-text" : "wing-text dim"}>{wing.state === "waiting" ? "Needs you" : "Working"}</span>
      );
    case "volume":
      return L ? <Glyph name="speaker" size={14} /> : <span className="level"><i style={{ transform: `scaleX(${wing.level})` }} /></span>;
    case "event":
      return L ? <Glyph name="calendar" size={14} /> : <span className="wing-text">{wing.text}</span>;
  }
}

const TABS = ["music", "waveform", "tray", "clipboard", "calendar", "timer", "sparkle", "grid", "gauge", "camera"];

function Panel({ s, mood, input }: { s: NotchState; mood: Mood; input: React.RefObject<HTMLInputElement | null> }) {
  const a = s.agent;
  const working = a.phase === "working";
  const showTranscript = a.request.length > 0 && a.phase !== "listening" && a.phase !== "transcribing";
  const send = () => {
    const text = a.draft.trim();
    if (!text) return;
    setAgent({ draft: "" });
    submitFromNotch(text);
  };
  return (
    <div className="panel-inner">
      <div className="panel-head">
        <span className="panel-title">
          <BlobFigure mood={mood} size={15} look="notch" active={s.open} />
          <span>Ask</span>
        </span>
        <span className="panel-gap" />
        <span className="panel-tabs" aria-hidden="true">
          {TABS.map((t) => (
            <span key={t} className={t === "waveform" ? "tab on" : "tab"}>
              <Glyph name={t} size={11} />
            </span>
          ))}
        </span>
      </div>
      <div className="panel-body">
        <div className="panel-content">
          {a.phase === "listening" ? (
            <div className="panel-center">
              <BlobFigure mood="curious" size={22} look="notch" active={s.open} />
              <VoiceBars bars={12} max={22} />
              <span className="ink-2">{a.request || "Listening…"}</span>
            </div>
          ) : a.phase === "transcribing" ? (
            <div className="panel-center">
              <BlobFigure mood="busy" size={20} look="none" active={s.open} />
              <span className="ink-2">Transcribing…</span>
            </div>
          ) : showTranscript ? (
            <div className="transcript">
              <p className="t-request">{a.request}</p>
              {a.steps.length > 0 && (
                <ul className="t-steps">
                  {a.steps.slice(-4).map((st, i) => (
                    <li key={i + st}>{st}</li>
                  ))}
                </ul>
              )}
              {a.phase === "failed" ? (
                <p className="t-reply dim">{a.error}</p>
              ) : working || !a.reply ? (
                <p className="t-working">
                  <BlobFigure mood="busy" size={14} look="none" active={s.open} />
                  <span>{(a.steps.at(-1) ?? "Thinking") + "…"}</span>
                </p>
              ) : (
                <p className="t-reply">{a.reply}</p>
              )}
            </div>
          ) : (
            <div className="panel-center">
              <BlobFigure mood="curious" size={22} look="notch" active={s.open} />
              <span>
                <strong>Tell Blob what to do on your Mac.</strong>
                <br />
                <span className="ink-2">Type below, or hold right ⌥ and talk.</span>
              </span>
            </div>
          )}
        </div>
        <form
          className="ask-bar"
          onSubmit={(e) => {
            e.preventDefault();
            send();
          }}
        >
          <Glyph name="waveform" size={11} className="ink-3" />
          <input
            ref={input}
            value={a.draft}
            onChange={(e) => setAgent({ draft: e.target.value })}
            placeholder="Tell Blob what to do…  or hold right ⌥"
            aria-label="Tell Blob what to do"
            spellCheck={false}
            autoComplete="off"
          />
          {working ? (
            <button type="button" className="ask-btn on" onClick={stopNotch} aria-label="Stop">
              <Glyph name="stop" size={11} />
            </button>
          ) : !a.draft && a.request ? (
            <button type="button" className="ask-btn" onClick={resetAgent} aria-label="New conversation">
              <Glyph name="plus" size={11} />
            </button>
          ) : (
            <button type="submit" className={a.draft ? "ask-btn on" : "ask-btn"} aria-label="Send">
              <Glyph name="up" size={12} />
            </button>
          )}
        </form>
      </div>
    </div>
  );
}
