/**
 * Damped springs with the app's exact presets (Blob/Core/Springs.swift), solved per frame.
 * SwiftUI's (response, dampingFraction) → stiffness k = (2π / response)², damping c = 4π·ζ / response.
 */
export type SpringPreset = { response: number; damping: number };

export const Springs = {
  open: { response: 0.42, damping: 0.74 },
  close: { response: 0.34, damping: 0.9 },
  snap: { response: 0.3, damping: 0.82 },
  soft: { response: 0.55, damping: 0.85 },
  wobble: { response: 0.38, damping: 0.58 },
} satisfies Record<string, SpringPreset>;

export class Spring {
  value: number;
  velocity = 0;
  target: number;
  private k = 0;
  private c = 0;

  constructor(value: number, preset: SpringPreset = Springs.snap) {
    this.value = value;
    this.target = value;
    this.use(preset);
  }

  use(preset: SpringPreset) {
    this.k = (2 * Math.PI / preset.response) ** 2;
    this.c = (4 * Math.PI * preset.damping) / preset.response;
  }

  to(target: number, preset?: SpringPreset) {
    if (preset) this.use(preset);
    this.target = target;
  }

  jump(value: number) {
    this.value = value;
    this.target = value;
    this.velocity = 0;
  }

  get settled() {
    return Math.abs(this.value - this.target) < 0.01 && Math.abs(this.velocity) < 0.01;
  }

  /** Semi-implicit Euler in small substeps: stable for every preset at any frame rate. */
  step(dt: number, reduce = false) {
    if (reduce) {
      this.jump(this.target);
      return this.value;
    }
    let remaining = dt;
    while (remaining > 0) {
      const h = Math.min(remaining, 1 / 240);
      const force = -this.k * (this.value - this.target) - this.c * this.velocity;
      this.velocity += force * h;
      this.value += this.velocity * h;
      remaining -= h;
    }
    if (this.settled) this.jump(this.target);
    return this.value;
  }
}
