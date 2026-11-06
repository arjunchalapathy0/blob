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

- `downloadUrl` — set it when there's a public, notarized download. Until then the page offers the
  source and says plainly that there's no download yet.
- `sourceUrl` — the repository (private today, so only invited people can open it).
- `siteUrl` — the deployed URL, used for metadata and the share image.
- `recordings` — real screen recordings (see below).

## Adding real recordings

Put files in `public/recordings/` and list them in `site.recordings`:

```ts
recordings: [{ scene: "focus", src: "/recordings/focus.mp4", poster: "/recordings/focus.jpg" }],
```

Scene ids: `focus`, `see`, `shortcut`, `asks`, `claude`. Each recording plays muted under that
scene's copy. Record with QuickTime (File → New Screen Recording) at 2× and export at 1080p.

## How it works

- **One notch** (`src/components/Notch.tsx`) is fixed to the top of the page. Sections take it over
  through a small store (`src/lib/notch.ts`): the hero demo, each scroll scene, the feature index,
  the moods.
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
node scripts/shoot.mjs shots         # screenshots: every section, desktop + mobile, light + dark
npx lighthouse@12.2.1 http://localhost:3000 --only-categories=performance,accessibility,best-practices,seo
```

## Deploy

Vercel: import the repository, set **Root Directory** to `blob-site`, framework **Next.js**. No
environment variables are needed.
