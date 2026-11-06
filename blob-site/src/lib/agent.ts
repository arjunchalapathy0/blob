/**
 * Plays a scripted request through the notch the way AgentService does it:
 * listening → transcribing → working (one step at a time) → done, with the same wings,
 * notices and timings the app uses.
 */
import { getNotch, headline, live, setAgent, setNotch } from "./notch";
import type { Script } from "./requests";
import { reducedMotion, subscribe } from "./ticker";

export class Cancelled extends Error {}

export function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) return reject(new Cancelled());
    const id = setTimeout(resolve, reducedMotion() ? Math.min(ms, 120) : ms);
    signal.addEventListener("abort", () => {
      clearTimeout(id);
      reject(new Cancelled());
    }, { once: true });
  });
}

/** A voice-like level: syllables riding on a slower phrase envelope. */
function startVoiceLevel(): () => void {
  const seed = Math.random() * 100;
  const stop = subscribe((t) => {
    const s = t + seed;
    const syllable = Math.abs(Math.sin(s * 8.3)) * (0.6 + 0.4 * Math.sin(s * 2.1));
    const phrase = 0.55 + 0.45 * Math.sin(s * 1.3);
    live.level = Math.max(0.08, Math.min(1, 0.15 + 0.75 * syllable * phrase));
  });
  return () => {
    stop();
    live.level = 0;
  };
}

type Run = {
  signal: AbortSignal;
  /** "voice": hold ⌥ and talk, notch stays closed with wings. "typed": typed into the open Ask tab. */
  mode: "voice" | "typed";
  /** For voice: resolves when the key is released. Without it, Blob "hears" the words on its own. */
  released?: Promise<number>;
  onOutcome?: (outcome: string) => void;
  /** Keep follow-ups in the same conversation (the app resumes within 10 minutes). */
  continuing?: boolean;
  /** The visitor typed it themselves: don't type it again. */
  skipTyping?: boolean;
};

export async function runScript(script: Script, run: Run): Promise<"done" | "ignored"> {
  const { signal, onOutcome } = run;
  const words = script.spoken.split(" ");
  const fresh = run.continuing ? {} : { steps: [] as string[] };

  if (run.mode === "voice") {
    setNotch({ open: getNotch().open, wing: { kind: "listening" } });
    setAgent({ phase: "listening", request: "", reply: "", error: "", followUp: "", ...fresh });
    const stopLevel = startVoiceLevel();
    try {
      const revealed: string[] = [];
      let heldFor = 0;
      if (run.released) {
        let done = false;
        const started = performance.now();
        run.released.then(() => (done = true));
        while (!done) {
          if (revealed.length < words.length && performance.now() - started > 300 + revealed.length * 230) {
            revealed.push(words[revealed.length]);
            setAgent({ request: revealed.join(" ") });
          }
          await sleep(40, signal);
        }
        heldFor = (performance.now() - started) / 1000;
        // AgentService ignores recordings shorter than 0.4 s.
        if (heldFor < 0.4) {
          setNotch({ wing: { kind: "none" } });
          setAgent({ phase: "idle", request: "" });
          return "ignored";
        }
      } else {
        for (const w of words) {
          await sleep(230, signal);
          revealed.push(w);
          setAgent({ request: revealed.join(" ") });
        }
        await sleep(350, signal);
      }
    } finally {
      stopLevel();
    }
    setNotch({ wing: { kind: "transcribing" } });
    setAgent({ phase: "transcribing", request: script.spoken });
    await sleep(650, signal);
  } else if (run.skipTyping) {
    setNotch({ open: true, wing: { kind: "none" } });
    setAgent({ draft: "", request: script.spoken, reply: "", error: "", followUp: "" });
  } else {
    setNotch({ open: true, wing: { kind: "none" } });
    setAgent({ phase: "idle", draft: "", reply: "", error: "", followUp: "", ...(run.continuing ? {} : { request: "", steps: [] }) });
    for (let i = 1; i <= script.spoken.length; i++) {
      setAgent({ draft: script.spoken.slice(0, i) });
      await sleep(28 + Math.random() * 40, signal);
    }
    await sleep(260, signal);
    setAgent({ draft: "", request: script.spoken });
  }

  // Working.
  setAgent({ phase: "working", reply: "", steps: run.continuing ? getNotch().agent.steps : [] });
  for (const step of script.steps) {
    const steps = getNotch().agent.steps;
    if (steps[steps.length - 1] !== step.label) setAgent({ steps: [...steps, step.label] });
    setNotch({ wing: { kind: "working", step: step.label } });
    if (step.outcome) onOutcome?.(step.outcome);
    await sleep(step.ms, signal);
  }

  // Done.
  setAgent({ phase: "done", reply: script.reply, followUp: script.followUp?.label ?? "" });
  if (script.outcome) onOutcome?.(script.outcome);
  setNotch({ wing: { kind: "notice", icon: "check", text: headline(script.reply) } });
  await sleep(4000, signal);
  setNotch({ wing: script.after === "music" ? { kind: "music" } : { kind: "none" } });
  return "done";
}
