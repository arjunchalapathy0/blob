/**
 * One requestAnimationFrame loop for the whole page. Everything that moves subscribes here,
 * writes styles through refs, and never touches React state per frame.
 */
type Tick = (now: number, dt: number) => void;

const subscribers = new Set<Tick>();
let raf = 0;
let last = 0;

function frame(now: number) {
  const dt = Math.min(0.05, last ? (now - last) / 1000 : 1 / 60);
  last = now;
  subscribers.forEach((fn) => fn(now / 1000, dt));
  raf = subscribers.size ? requestAnimationFrame(frame) : 0;
}

/** Motion starts once the page has loaded, so it never competes with the first paint. */
let started = false;
let waiting = false;
function kick() {
  if (raf || !subscribers.size) return;
  if (!started) {
    if (waiting) return;
    waiting = true;
    const go = () => {
      if (started) return;
      started = true;
      waiting = false;
      kick();
    };
    const idle = () =>
      "requestIdleCallback" in window
        ? window.requestIdleCallback(go, { timeout: 1500 })
        : setTimeout(go, 400);
    // Any interaction starts motion at once.
    const early = () => {
      if (!started) go();
    };
    window.addEventListener("pointermove", early, { once: true, passive: true });
    window.addEventListener("keydown", early, { once: true });
    window.addEventListener("scroll", early, { once: true, passive: true });
    if (document.readyState === "complete") idle();
    else window.addEventListener("load", idle, { once: true });
    return;
  }
  last = 0;
  raf = requestAnimationFrame(frame);
}

export function subscribe(fn: Tick): () => void {
  subscribers.add(fn);
  if (typeof window !== "undefined") kick();
  return () => {
    subscribers.delete(fn);
  };
}

export function reducedMotion(): boolean {
  return typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}
