# Blob site — design

## Direction: Aluminium

The page is the machine. Light mode is the anodized lid of a MacBook in daylight; dark mode is the
screen at night. Against that, exactly one thing is pure black: the notch. Blob lives there, and the
eye should always land there first.

Rejected: *Night shift* (all-black page; collapses into the dark-plus-accent default and loses Blob's
softness) and *Silent film* (intertitles and grain; charming, but a gimmick and grain costs
performance). From Silent film we keep one idea: the use cases are **scenes** played on one stage,
because they really are a sequence.

## Palette

No accent colour. Blob is monochrome in the app; the site is too.

| Token | Light (lid) | Dark (screen) | Use |
|---|---|---|---|
| `--metal` | `#C9CACD` | `#17181A` | page surface |
| `--metal-hi` | `#D8D9DB` | `#202124` | raised surface: the stage, keycaps |
| `--metal-lo` | `#B7B8BC` | `#0F1011` | engraved lines, recesses |
| `--graphite` | `#232427` | `#E6E6E8` | text |
| `--graphite-2` | `#5B5C61` | `#9A9BA0` | secondary text (≥ 4.5:1 on `--metal`) |
| `--notch` | `#000000` | `#000000` | the notch, and nothing else |
| `--blob` | `#949498` | `#949498` | the character, as in the app (`Color(white: 0.58)`) |

Inside the notch, the app's own ink: white at 100 / 56 / 32 % and fills at 7 / 14 %.

## Type

- **Display: Bricolage Grotesque** (variable, optical size 96, weight 700–800, width 75–85).
  Condensed and slightly quirky at large sizes: it looks engraved into the lid rather than printed on
  it. Tracking −0.04em at the top of the scale, −0.02em at h3.
- **Text: Newsreader** (variable, optical size). A text serif for the copy, so the voice reads like a
  person, not a feature list. 19/30 at desktop, 17/27 on mobile. Line length 34–38em max.
- **Product UI: the system's rounded face** (`ui-rounded`, SF Pro Rounded), exactly what the app
  uses. Only inside the notch and on keycaps.

Scale (1.333, rounded to the 8px rhythm): 14 · 17 · 19 · 24 · 32 · 44 · 64 · 88 · 128 (clamped by
viewport). Never more than two sizes per block. No all-caps labels, no eyebrows, no mid-dot meta
strings, no monospace labels, no arrows appended to links.

## Grid and rhythm

- 12 columns, 1280px max, 24px gutters; 16px page margin on mobile.
- Vertical rhythm on an 8px base. Section spacing: 168 (desktop) / 104 (mobile). Inside blocks:
  8, 16, 24, 40, 64.
- Content is left-aligned. The only centred object is the notch, because it is centred on a real
  Mac.
- Structure is drawn with **engraved hairlines** (a 1px `--metal-lo` line over a 1px highlight),
  never with cards or shadows. The one raised surface is the stage, a screen inset into the lid.

## Motion

- Every animation is a spring taken from `Blob/Core/Springs.swift`:
  `open` (response 0.42, damping 0.74), `close` (0.34, 0.9), `snap` (0.3, 0.82), `soft` (0.55, 0.85),
  `wobble` (0.38, 0.58). Solved per frame, not CSS easing approximations.
- The character runs the app's motion engine (`Mood.pose(at:)`), ported line for line, with moods
  blended by the app's damped spring.
- Motion only answers something: a request being carried out, a scroll into a scene, a hover. No
  fade-up-on-scroll for text. Nothing loops on the page except Blob itself breathing.
- `prefers-reduced-motion`: springs jump to their end state, the character holds still (blinks only),
  scenes show their final frame.
- Only `transform` and `opacity` animate outside the notch; the notch's size animates on one element
  whose box never affects layout.

## Details

- Cursor: over the notch the cursor becomes a soft dot and Blob's eyes follow it (the app's
  `lookGain`). Keycaps press down on click and when the real right ⌥ key is held.
- Focus: a 2px graphite ring offset 3px, white inside the notch.
- Copy: short, plain, specific, a little dry. Blob's own lines are the app's real strings.

## Content rules

Every claim maps to code in this repo. Request flows use the app's real step labels
(`ClaudeCLI.stepLabel`) and its real rules (asks before deleting, sending, buying).

---

## Addendum (owner, at build time): one notch for the whole page

The owner asked for Blob to be alive across the entire site and for scroll-driven animation. This
sharpens the direction rather than changing it:

- **There is exactly one notch, and it never leaves.** It is fixed to the top centre of the viewport,
  hanging from a thin menu-bar strip, like the real one hangs from the bezel. The hero demo, every
  scene, the feature index and the moods all drive *that* notch. Scrolling the page is scrolling the
  desktop underneath it.
- **Blob reacts to the page.** It looks where you scroll (down while you scroll down, up when you go
  back), looks at the pointer, takes the mood each section is about, and falls asleep at the
  footer. Hovering a feature in the index makes the notch show that feature's real wings.
- **Scroll animation is scene-driven, not decorative.** The scenes section pins one desktop and
  plays each scene on the notch as you scroll into it; windows on the desktop move with scroll
  progress. Text never fades up on its own.
- The rest of the page uses windows (raised `--metal-hi` surfaces with an engraved edge, no
  shadows) to show outcomes on the "desktop". The desktop picture is Blob itself, engraved into the
  screen, sharing the notch's mood and peeking out from behind whatever window is open.

## Changes made while building (and why)

- **Optical size axis dropped from both fonts.** With `opsz` the two preloaded variable files were
  ~130 KB each and mobile Lighthouse sat at 85–92. Bricolage Grotesque keeps its `wdth` axis (the
  condensed cut is the point); Newsreader uses its default optical size. Display tracking was kept.
- **No italic file.** Quotes are set upright in Newsreader with real quotation marks.
- **CSS transitions use the app's springs too:** the few CSS transitions use `linear()` easings
  sampled from the same solver (`scripts/spring-easings.mjs`), so they are the springs, not
  approximations.
- **Motion starts after load** (on idle, or the first pointer move, key or scroll), so it never
  competes with first paint.
