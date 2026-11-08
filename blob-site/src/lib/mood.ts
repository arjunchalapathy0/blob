/**
 * Blob's motion engine, ported line for line from Blob/Core/Character/Mood.swift
 * and BlobCharacter.springProgress.
 */
export type Mood = "idle" | "curious" | "happy" | "busy" | "alarmed" | "sleepy";

export type Pose = {
  sx: number; sy: number; dx: number; dy: number; rot: number;
  eyeOpen: number; eyeScale: number; eyeShift: number; lookGain: number; z: number;
};

const base = (): Pose => ({
  sx: 1, sy: 1, dx: 0, dy: 0, rot: 0, eyeOpen: 1, eyeScale: 1, eyeShift: 0, lookGain: 1, z: 0,
});

const TAU = 2 * Math.PI;
const fract = (x: number) => x - Math.floor(x);

export function blink(t: number): number {
  const period = 4.6;
  const cycle = Math.floor(t / period);
  const local = t - cycle * period;
  const dip = (x: number) => (x >= 0 && x < 0.14 ? Math.abs(Math.cos((Math.PI * x) / 0.14)) : 1);
  const first = dip(local);
  const second = ((cycle % 3) + 3) % 3 === 0 ? dip(local - 0.22) : 1;
  return Math.min(first, second);
}

export function pose(mood: Mood, t: number): Pose {
  const s = (period: number, phase = 0) => Math.sin((TAU * t) / period + phase);
  const p = base();
  switch (mood) {
    case "idle": {
      const b = s(3.6);
      p.sy = 1 + 0.028 * b;
      p.sx = 1 - 0.018 * b;
      p.eyeShift = 0.25 * s(9.0);
      p.eyeOpen = blink(t);
      break;
    }
    case "curious": {
      const b = s(2.8);
      p.sy = 1.04 + 0.02 * b;
      p.sx = 0.98;
      p.dy = -0.04;
      p.rot = 5 + 2 * s(4.2);
      p.eyeScale = 1.18;
      p.lookGain = 1.4;
      p.eyeOpen = blink(t + 1.3);
      break;
    }
    case "happy": {
      const phase = fract(t * 2.0);
      const air = Math.sin(Math.PI * phase);
      const land = Math.pow(1 - air, 6);
      p.dy = -0.16 * air;
      p.sy = 1 - 0.1 * land + 0.04 * air;
      p.sx = 1 + 0.08 * land - 0.02 * air;
      p.rot = 3 * s(1.0);
      p.eyeOpen = 0.5;
      p.lookGain = 0.6;
      break;
    }
    case "busy": {
      p.rot = 4 * s(0.42);
      p.sx = 1 + 0.03 * s(0.21);
      p.sy = 1 - 0.03 * s(0.21);
      p.eyeShift = s(1.4);
      p.eyeOpen = 0.78 * blink(t + 0.7);
      p.lookGain = 0.2;
      break;
    }
    case "alarmed": {
      const e = Math.exp(-3.2 * fract(t / 1.2));
      p.dy = -0.22 * e;
      p.sy = 1 + 0.12 * e;
      p.sx = 1 - 0.06 * e;
      p.dx = 0.05 * e * s(0.09);
      p.rot = 8 * e * s(0.16);
      p.eyeScale = 1.35;
      p.lookGain = 0.3;
      break;
    }
    case "sleepy": {
      const b = s(5.2);
      p.sy = 0.9 + 0.035 * b;
      p.sx = 1.06 - 0.02 * b;
      p.dy = 0.04;
      p.rot = -5;
      p.eyeOpen = 0.1;
      p.lookGain = 0;
      p.z = 1;
      break;
    }
  }
  return p;
}

/** Reduced motion: the pose holds still, only the blink stays. */
export function stillPose(mood: Mood, t: number): Pose {
  const p = pose(mood, 0);
  if (mood !== "sleepy" && mood !== "happy") p.eyeOpen = Math.min(p.eyeOpen, 1) * blink(t);
  p.z = 0;
  return p;
}

export function lerpPose(a: Pose, b: Pose, t: number): Pose {
  const m = (x: number, y: number) => x + (y - x) * t;
  return {
    sx: m(a.sx, b.sx), sy: m(a.sy, b.sy), dx: m(a.dx, b.dx), dy: m(a.dy, b.dy), rot: m(a.rot, b.rot),
    eyeOpen: m(a.eyeOpen, b.eyeOpen), eyeScale: m(a.eyeScale, b.eyeScale), eyeShift: m(a.eyeShift, b.eyeShift),
    lookGain: m(a.lookGain, b.lookGain), z: m(a.z, b.z),
  };
}

/** Damped spring from 0 to 1 with a small overshoot, used to blend between moods. */
export function springProgress(dt: number): number {
  if (dt <= 0) return 0;
  if (dt >= 1.4) return 1;
  return 1 - Math.exp(-6.5 * dt) * Math.cos(9.5 * dt);
}

export const MOODS: { mood: Mood; name: string; when: string }[] = [
  { mood: "idle", name: "Idle", when: "Nothing going on. Breathes, blinks, glances around." },
  { mood: "curious", name: "Curious", when: "You hover the notch. Leans in and watches your pointer." },
  { mood: "happy", name: "Happy", when: "Music is playing. Hops, roughly on the beat." },
  { mood: "busy", name: "Busy", when: "Claude is working on something. Wiggles, eyes reading left to right." },
  { mood: "alarmed", name: "Alarmed", when: "A timer ran out, or Claude needs you. Jumps." },
  { mood: "sleepy", name: "Sleepy", when: "Left alone for ten minutes. Squashes down, eyes shut." },
];
