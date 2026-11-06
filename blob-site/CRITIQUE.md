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
