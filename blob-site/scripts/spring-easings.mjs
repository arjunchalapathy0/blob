// Bakes the app's springs (Blob/Core/Springs.swift) into CSS linear() easings for the few
// places CSS transitions are used. Same solver as src/lib/spring.ts.
const presets = { open: [0.42, 0.74], close: [0.34, 0.9], snap: [0.3, 0.82], soft: [0.55, 0.85], wobble: [0.38, 0.58] };
for (const [name, [response, damping]] of Object.entries(presets)) {
  const k = (2 * Math.PI / response) ** 2, c = (4 * Math.PI * damping) / response;
  let x = 0, v = 0, t = 0;
  const samples = [];
  const h = 1 / 960;
  while (t < 3) {
    const f = -k * (x - 1) - c * v;
    v += f * h; x += v * h; t += h;
    samples.push([t, x]);
    if (t > 0.1 && Math.abs(x - 1) < 0.001 && Math.abs(v) < 0.01) break;
  }
  const dur = t;
  const pts = [];
  const N = 36;
  for (let i = 0; i <= N; i++) {
    const target = (i / N) * dur;
    const s = samples.find((p) => p[0] >= target) ?? samples[samples.length - 1];
    pts.push(Number(s[1].toFixed(3)));
  }
  pts[pts.length - 1] = 1;
  console.log(`  --spring-${name}: linear(0, ${pts.slice(1).join(", ")});`);
  console.log(`  --spring-${name}-dur: ${Math.round(dur * 1000)}ms;`);
}
