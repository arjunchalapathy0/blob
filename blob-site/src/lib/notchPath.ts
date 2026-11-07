/**
 * Blob/Core/NotchShape.swift as an SVG/CSS path: flush with the top, small concave "ears",
 * continuous bottom corners. The frame includes the ears; the body is width − 2·topRadius wide.
 */
export function notchPath(x: number, y: number, w: number, h: number, topRadius: number, bottomRadius: number): string {
  const k = 1.28;
  const tr = Math.max(0, Math.min(topRadius, w / 4, h / 2));
  const br = Math.max(0, Math.min(bottomRadius, (w - 2 * tr) / (2 * k), (h - tr) / k));
  const minX = x, minY = y, maxX = x + w, maxY = y + h;
  const left = minX + tr, right = maxX - tr;
  const f = (n: number) => Math.round(n * 100) / 100;
  return [
    `M${f(minX)},${f(minY)}`,
    `C${f(minX + tr * 0.62)},${f(minY)} ${f(left)},${f(minY + tr * 0.38)} ${f(left)},${f(minY + tr)}`,
    `L${f(left)},${f(maxY - br * k)}`,
    `C${f(left)},${f(maxY - br * 0.26)} ${f(left + br * 0.26)},${f(maxY)} ${f(left + br * k)},${f(maxY)}`,
    `L${f(right - br * k)},${f(maxY)}`,
    `C${f(right - br * 0.26)},${f(maxY)} ${f(right)},${f(maxY - br * 0.26)} ${f(right)},${f(maxY - br * k)}`,
    `L${f(right)},${f(minY + tr)}`,
    `C${f(right)},${f(minY + tr * 0.38)} ${f(maxX - tr * 0.62)},${f(minY)} ${f(maxX)},${f(minY)}`,
    "Z",
  ].join(" ");
}

/** A continuous-corner rounded rectangle (the character's body), same corner construction. */
export function squirclePath(x: number, y: number, w: number, h: number, r: number): string {
  const k = 1.28;
  const rr = Math.min(r, w / (2 * k), h / (2 * k));
  const f = (n: number) => Math.round(n * 1000) / 1000;
  const a = rr * k, b = rr * 0.26;
  const X = x + w, Y = y + h;
  return [
    `M${f(x + a)},${f(y)}`,
    `L${f(X - a)},${f(y)}`,
    `C${f(X - b)},${f(y)} ${f(X)},${f(y + b)} ${f(X)},${f(y + a)}`,
    `L${f(X)},${f(Y - a)}`,
    `C${f(X)},${f(Y - b)} ${f(X - b)},${f(Y)} ${f(X - a)},${f(Y)}`,
    `L${f(x + a)},${f(Y)}`,
    `C${f(x + b)},${f(Y)} ${f(x)},${f(Y - b)} ${f(x)},${f(Y - a)}`,
    `L${f(x)},${f(y + a)}`,
    `C${f(x)},${f(y + b)} ${f(x + b)},${f(y)} ${f(x + a)},${f(y)}`,
    "Z",
  ].join(" ");
}

/** The app's geometry constants (NotchViewModel). */
export const NOTCH = {
  width: 185,
  height: 32,
  openWidth: 720,
  openExtra: 178,
};
