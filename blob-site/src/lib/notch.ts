/**
 * The one notch on the page, as a small store. Sections take it over when they need it
 * (the hero demo, a scene, the feature index), and give it back when they're done.
 */
import { useSyncExternalStore } from "react";
import type { Mood } from "./mood";

export type Wing =
  | { kind: "none" }
  | { kind: "listening" }
  | { kind: "transcribing" }
  | { kind: "working"; step: string }
  | { kind: "notice"; icon: "check" | "warn" | "ear" | "bolt" | "copy"; text: string }
  | { kind: "music" }
  | { kind: "timer"; text: string }
  | { kind: "timerDone" }
  | { kind: "claude"; state: "working" | "waiting" }
  | { kind: "volume"; level: number }
  | { kind: "event"; text: string };

export type AgentPhase = "idle" | "listening" | "transcribing" | "working" | "done" | "failed";

export type AgentPanel = {
  phase: AgentPhase;
  request: string;
  draft: string;
  steps: string[];
  reply: string;
  error: string;
  followUp: string;
};

export type NotchState = {
  wing: Wing;
  open: boolean;
  peek: boolean;
  mood: Mood;
  agent: AgentPanel;
  owner: string | null;
  /** Keep the open notch open until this time (ms), e.g. so a reply can be read. */
  holdUntil: number;
};

const idleAgent: AgentPanel = { phase: "idle", request: "", draft: "", steps: [], reply: "", error: "", followUp: "" };

let state: NotchState = { wing: { kind: "none" }, open: false, peek: false, mood: "idle", agent: idleAgent, owner: null, holdUntil: 0 };
const listeners = new Set<() => void>();

/** Values that change every frame live outside React. */
export const live = { level: 0, lookX: 0, lookY: 0, scrollLook: 0, px: -9999, py: -9999 };

export function getNotch() {
  return state;
}

export function setNotch(patch: Partial<NotchState>) {
  state = { ...state, ...patch };
  listeners.forEach((l) => l());
}

export function setAgent(patch: Partial<AgentPanel>) {
  setNotch({ agent: { ...state.agent, ...patch } });
}

export function useNotch(): NotchState {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => state,
    () => state,
  );
}

let cancelOwner: (() => void) | null = null;

/** Takes the notch; whoever had it is told to stop. */
export function takeNotch(owner: string, onCancel: () => void) {
  if (state.owner !== owner && cancelOwner) {
    const c = cancelOwner;
    cancelOwner = null;
    c();
  }
  cancelOwner = onCancel;
  setNotch({ owner });
}

/** Gives the notch back and lets it settle to idle. */
export function releaseNotch(owner: string, mood: Mood = "idle") {
  if (state.owner !== owner) return;
  cancelOwner = null;
  setNotch({ owner: null, wing: { kind: "none" }, open: false, peek: false, mood, agent: idleAgent });
}

export function resetAgent() {
  setNotch({ agent: idleAgent });
}

/** The ambient mood the page asks for when nobody owns the notch. */
export function setAmbientMood(mood: Mood) {
  if (state.owner === null && state.mood !== mood) setNotch({ mood });
}

/** First sentence, short enough for the notch (AgentService.headline). */
export function headline(text: string): string {
  const flat = text.replace(/\n/g, " ").trim();
  const sentence = flat.split(".")[0] ?? flat;
  if (!sentence) return "Done";
  return sentence.length > 28 ? sentence.slice(0, 27) + "…" : sentence;
}

/** Whoever handles text sent from the notch's input (the hero registers this). */
let submitHandler: ((text: string) => void) | null = null;
export function onNotchSubmit(fn: (text: string) => void) {
  submitHandler = fn;
  return () => {
    if (submitHandler === fn) submitHandler = null;
  };
}
export function submitFromNotch(text: string) {
  submitHandler?.(text);
}

/** The stop button: cancels whatever is running. */
export function stopNotch() {
  const owner = state.owner;
  if (cancelOwner) {
    const c = cancelOwner;
    cancelOwner = null;
    c();
  }
  if (owner) releaseNotch(owner);
  setNotch({ open: true });
}
