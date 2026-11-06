// Screenshots every section at desktop and mobile, light and dark, plus reduced motion and
// mid-request frames of the hero demo. Usage: node scripts/shoot.mjs <out_dir> [url]
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import fs from "node:fs";

const out = process.argv[2] ?? "shots";
const url = process.argv[3] ?? "http://localhost:3000";
fs.mkdirSync(out, { recursive: true });

const sections = ["demo", "scenes", "moods", "everything", "privacy", "iphone", "get"];
const sizes = { desktop: { width: 1440, height: 900 }, mobile: { width: 390, height: 844 } };

const browser = await chromium.launch();
for (const [sizeName, viewport] of Object.entries(sizes)) {
  for (const scheme of ["light", "dark"]) {
    const ctx = await browser.newContext({ viewport, colorScheme: scheme, deviceScaleFactor: 1, hasTouch: sizeName === "mobile", isMobile: sizeName === "mobile" });
    const page = await ctx.newPage();
    await page.goto(url, { waitUntil: "networkidle" });
    await page.waitForTimeout(600);
    await page.screenshot({ path: `${out}/${sizeName}-${scheme}-00-top.png` });
    for (const [i, id] of sections.entries()) {
      if (id === "scenes") {
        const top = await page.evaluate(() => document.getElementById("scenes").offsetTop);
        const vh = viewport.height;
        for (let s = 0; s < 5; s++) {
          await page.evaluate(([y]) => window.scrollTo(0, y), [top + vh * (s + 0.35)]);
          await page.waitForTimeout(s === 0 ? 3800 : 3800);
          await page.screenshot({ path: `${out}/${sizeName}-${scheme}-0${i + 1}-scenes-${s + 1}.png` });
        }
        continue;
      }
      await page.evaluate((id) => document.getElementById(id).scrollIntoView({ block: "start" }), id);
      await page.waitForTimeout(700);
      await page.screenshot({ path: `${out}/${sizeName}-${scheme}-0${i + 1}-${id}.png` });
    }
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(600);
    await page.screenshot({ path: `${out}/${sizeName}-${scheme}-99-footer.png` });
    await ctx.close();
  }
}

// Hero demo frames (desktop light): hold right ⌥, then watch it work.
{
  const ctx = await browser.newContext({ viewport: sizes.desktop, colorScheme: "light" });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  await page.waitForTimeout(400);
  await page.keyboard.down("AltRight");
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${out}/demo-1-listening.png` });
  await page.keyboard.up("AltRight");
  await page.waitForTimeout(1400);
  await page.screenshot({ path: `${out}/demo-2-working.png` });
  await page.waitForTimeout(2600);
  await page.screenshot({ path: `${out}/demo-3-done.png` });
  // Typed request: open panel and type.
  await page.getByRole("button", { name: "What does this error mean?" }).click();
  await page.waitForTimeout(2600);
  await page.screenshot({ path: `${out}/demo-4-typed.png` });
  await page.waitForTimeout(2600);
  await page.screenshot({ path: `${out}/demo-5-typed-done.png` });
  // Hover the notch.
  await page.mouse.move(720, 12);
  await page.waitForTimeout(900);
  await page.screenshot({ path: `${out}/demo-6-hover.png` });
  await ctx.close();
}

// Reduced motion, once.
{
  const ctx = await browser.newContext({ viewport: sizes.desktop, colorScheme: "light", reducedMotion: "reduce" });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${out}/reduced-top.png` });
  await page.evaluate(() => document.getElementById("moods").scrollIntoView());
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${out}/reduced-moods.png` });
  await ctx.close();
}
await browser.close();
console.log("done", out);
