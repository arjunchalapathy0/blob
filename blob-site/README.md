# blob-site

The marketing site for Blob. Next.js (App Router, static), hand-written CSS, no UI or animation
libraries. Design direction and rules: [DESIGN.md](DESIGN.md). Review rounds: [CRITIQUE.md](CRITIQUE.md).

## Run it

```bash
cd blob-site
npm install
npm run dev        # http://localhost:3000
npm run build && npm start
```

## Things you'll want to change

All in [`src/lib/site.ts`](src/lib/site.ts):

- `sourceUrl` — the repository, linked from the footer.
- `siteUrl` — the deployed URL, used for metadata and the share image.
- `recordings` — real screen recordings (see below).

## Downloads

The download buttons appear by themselves once a release workflow has published a build:

- **Mac:** Actions → *Mac release* → Run workflow. It builds Blob.app, and commits
  `public/Blob.zip` and `public/version.json` (which the app's Update button reads).
- **Windows:** Actions → *Windows release* → Run workflow. It commits `public/windows/`.

Vercel redeploys on that commit. See `src/lib/releases.ts`.

## Adding real recordings

Put files in `public/recordings/` and list them in `site.recordings`:

```ts
recordings: [{ scene: "focus", src: "/recordings/focus.mp4", poster: "/recordings/focus.jpg" }],
```

Scene ids: `focus`, `see`, `shortcut`, `asks`, `claude`. Each recording plays muted under that
scene's copy. Record with QuickTime (File → New Screen Recording) at 2× and export at 1080p.

## How it works

- **The notch** (`src/components/Notch.tsx`) is drawn inside each screen (`.screen`). The screens
  share one state through a small store (`src/lib/notch.ts`): whichever section is in view takes
  it over (the hero demo, then each scroll scene) and gives it back when it leaves.
- **A screen** is drawn in Mac points and scaled as one piece (`src/lib/useScreenFit.ts`), so the
  notch, menu bar and windows (`src/components/Desktop.tsx`) keep their real proportions.
- **The travelling Blob** (`src/components/BlobActor.tsx`) moves between elements marked
  `blob-anchor`; the nearest one to the middle of the window wins.
- **The character** (`src/components/BlobFigure.tsx`, `src/lib/mood.ts`) is a line-for-line port
  of `Blob/Core/Character/Mood.swift` and `BlobCharacter.swift`.
- **The notch shape** (`src/lib/notchPath.ts`) is `Blob/Core/NotchShape.swift`.
- **Springs** (`src/lib/spring.ts`) use the app's presets from `Blob/Core/Springs.swift`; one
  requestAnimationFrame loop (`src/lib/ticker.ts`) drives everything and writes styles directly.
- **Requests** (`src/lib/requests.ts`, `src/lib/agent.ts`) play the app's real phases, step labels
  and safety rules.

## Checks

```bash
npm run lint && npm run build && npm start &
node scripts/shoot.mjs shots         # screenshots: every section, desktop + phone, plus the demo
npx lighthouse@12.2.1 http://localhost:3000 --only-categories=performance,accessibility,best-practices,seo
```

## Deploy

Vercel: import the repository, set **Root Directory** to `blob-site`, framework **Next.js**. No
environment variables are needed.
