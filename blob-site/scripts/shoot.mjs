// Screenshots of every section at desktop and phone size, plus the hero demo mid-request and
// the page with reduced motion. Usage: node scripts/shoot.mjs <out_dir> [url]
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import fs from "node:fs";

const out = process.argv[2] ?? "shots";
const url = process.argv[3] ?? "http://localhost:3000";
fs.mkdirSync(out, { recursive: true });

const sections = ["demo", "scenes", "moods", "features", "privacy", "get"];
const sizes = { desktop: { width: 1440, height: 900 }, mobile: { width: 390, height: 844 } };

const browser = await chromium.launch();
for (const [sizeName, viewport] of Object.entries(sizes)) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: 1, hasTouch: sizeName === "mobile", isMobile: sizeName === "mobile" });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  await page.waitForTimeout(4200);
  await page.screenshot({ path: `${out}/${sizeName}-00-top.png` });
  for (const [i, id] of sections.entries()) {
    if (id === "scenes") {
      // The pinned section: one frame per scene, each given time to play.
      const { top, height } = await page.evaluate(() => {
        const el = document.getElementById("scenes");
        return { top: el.offsetTop, height: el.offsetHeight };
      });
      const total = height - viewport.height;
      for (let s = 0; s < 5; s++) {
        await page.evaluate(([y]) => window.scrollTo(0, y), [top + ((s + 0.4) / 5) * total]);
        await page.waitForTimeout(3800);
        await page.screenshot({ path: `${out}/${sizeName}-0${i + 1}-scenes-${s + 1}.png` });
      }
      continue;
    }
    await page.evaluate((id) => {
      const el = document.getElementById(id);
      window.scrollTo(0, el.getBoundingClientRect().top + window.scrollY - 70);
    }, id);
    await page.waitForTimeout(id === "demo" ? 5200 : 1400);
    await page.screenshot({ path: `${out}/${sizeName}-0${i + 1}-${id}.png` });
  }
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(1200);
  await page.screenshot({ path: `${out}/${sizeName}-99-footer.png` });
  await ctx.close();
}

// The demo, driven by hand: hold right ⌥, then pick a typed request.
{
  const ctx = await browser.newContext({ viewport: sizes.desktop });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  await page.evaluate(() => {
    const el = document.getElementById("demo");
    window.scrollTo(0, el.getBoundingClientRect().top + window.scrollY - 70);
  });
  await page.waitForTimeout(400);
  await page.keyboard.down("AltRight");
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${out}/demo-1-listening.png` });
  await page.keyboard.up("AltRight");
  await page.waitForTimeout(1600);
  await page.screenshot({ path: `${out}/demo-2-working.png` });
  await page.waitForTimeout(3200);
  await page.screenshot({ path: `${out}/demo-3-done.png` });
  await page.getByRole("button", { name: "What does this error mean?" }).click();
  await page.waitForTimeout(5200);
  await page.screenshot({ path: `${out}/demo-4-typed.png` });
  await ctx.close();
}

// Reduced motion: everything is in place without animation.
{
  const ctx = await browser.newContext({ viewport: sizes.desktop, reducedMotion: "reduce" });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  await page.waitForTimeout(800);
  await page.screenshot({ path: `${out}/reduced-top.png` });
  await page.evaluate(() => document.getElementById("moods").scrollIntoView());
  await page.waitForTimeout(600);
  await page.screenshot({ path: `${out}/reduced-moods.png` });
  await ctx.close();
}

await browser.close();
console.log(`Saved to ${out}/`);
