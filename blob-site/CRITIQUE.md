# Critique rounds

Screenshots of every section at 1440×900 and 390×844, light and dark, plus hero mid-request frames
and reduced motion (`node scripts/shoot.mjs <dir>`), checked against the bans in the brief and
DESIGN.md after each round.

## Round 1

| What was wrong | What changed |
|---|---|
| The ⌥ in the hero headline fell back to a system glyph: thin, misaligned, the one thing on the page that looked accidental. | Drawn as an inline key: a graphite keycap sized to the cap height, ⌥ set in the product's rounded face. |
| 216px of empty metal above the headline; the keycap fell below the fold at 1440×900. | Hero top space cut to 128px; the open notch overlays the copy briefly, like the real one. |
| The idle stage was an empty grey rectangle: decoration without information. | The desktop picture is now Blob itself, engraved into the screen, with the notch's mood and eyes that follow the pointer. It peeks out from behind the terminal. |
| A reply with "6.2 GB" was cut at the decimal point in the notch notice (the app splits at the first full stop). The notice clipped mid-word. | Reply rewritten without decimals; notice text gets an ellipsis at the wing's width, as in the app. |
| Scene ticks and the big scene number said the same thing twice. | Ticks removed; the engraved number stays. |
| The moods stage read as a black bucket, not a notch, and the six mood buttons wrapped 5 + 1. | The notch now hangs from an engraved bezel line at real-ish proportions; buttons sit in a 3×2 grid. |
| Mobile: toast and calendar windows overlapped; the 150px Blob overflowed its stage. | Phone-sized window layout; Blob scales with its stage. |

## Round 2

| What was wrong | What changed |
|---|---|
| Mobile Lighthouse 85: ~560ms of style/layout from reading element sizes every frame (notch width, wing width, Blob positions). | Sizes cached on resize and via ResizeObserver/IntersectionObserver; every per-frame write skipped when the value is unchanged; hidden Blobs (inside the closed notch) pause. |
| Three preloaded fonts (~400KB) delayed LCP to 3.9s. | Italic file dropped; optical-size axes dropped (58 + 78 KB). Mobile LCP 2.4s. |
| Accessibility 94: `aria-label` on a plain span; the keycap's name didn't contain its visible text; the scenes h2 was `display:none` on mobile, breaking heading order. | Screen-reader text instead of the span label; keycap named "Hold to talk, ⌥ option" and described by the line next to it; the h2 is visually hidden instead of removed. |
| Animation started during load and competed with first paint. | The single rAF loop starts on idle after load, or at the first pointer move, key or scroll. |

## Round 3

| What was wrong | What changed |
|---|---|
| After a typed request, a ghost of the previous notice showed behind the open panel: React re-created the wing elements, which lost their spring-written opacity. | Wing containers are stable; the ticker re-writes their styles whenever the wing changes. |
| Share image used a default font and a ⌥ glyph the renderer couldn't load. | Built with the display face, with a drawn "option" key. |

Final checks: no horizontal scroll at 320px; keyboard order (skip link, menu, Talk to Blob, theme,
Get Blob, keycap, requests, moods, index…); the keycap works with Space held; reduced motion shows
final frames and a still, blinking Blob.

## Round 4: the owner's verdict

The owner looked at v1 and didn't like it (“straight ass cheeks”). Honest read: flat grey, a notch too
small to notice, wireframe-looking windows, big empty gaps, and no moment that stops the scroll.
They chose a mix of *cinematic* and *Blob is the star*, and named “too empty” and “not impressive”.

| What was wrong | What changed |
|---|---|
| The grey aluminium page was dull. | A black page with lit Mac screens; type in near-white. |
| Nothing impressive up top. | A scroll-driven opening: a full-window Mac screen, the camera pushes into the notch, it springs open, Blob drops onto a 200px headline. |
| Blob was tiny or absent. | One big Blob travels the whole page with spring physics, perching on the demo screen, each scene title, the moods stage, the feature index, the headline and the footer. |
| The notch was small, at the top of the viewport. | The real notch, scaled ~1.7×, at the top of a big Mac screen in the demo; scaled copies in the scenes and the feature index. |
| The demo sat empty until you acted. | It runs through the requests by itself while on screen, until you touch it. |
| Moods were a small panel. | A 300px Blob in the middle of the page with the mood's name set enormous behind it. |
| Blob covered text on its perches (it was placed by its unscaled box). | Placed by its bottom centre, which is what scales. |

## Round 5 — "it's laggy and the font is bad"

- **Lag:** an A/B profile showed one culprit: a `drop-shadow` filter on the travelling Blob, re-rasterized every frame. Removing it took scroll frames from ~50 ms to a steady 16.7 ms.
- **Type:** Bricolage/Newsreader replaced with Geist (display + body), Instrument Serif italic for one accent word per headline, Geist Mono for chapter labels. Fixed scale: 152 / 104 / 72 / 24 / 19 / 15 / 12.
- **Pacing:** the page reads as chapters (01 Try it … 08 Get Blob), with larger section spacing, reveal-on-scroll, and a reading-progress line in the bar.
- **Mood:** a 50 KB rendered loop (dust in a shaft of light from the notch) behind the headline and the closing chapter. It plays only on screen and stays still with reduced motion.
- **Imagery:** an interlude of three art-directed renders of Blob (the notch, the ⌥ key, asleep). They are renders, not photos; real photography can replace them in `public/media/`.
- Lighthouse after: mobile 95 / 100 / 100 / 100, desktop 100 ×4, CLS 0.
