# Blob site — design

## Direction: Studio

A monochrome product studio. The page is a run of rooms: black rooms, and sheets of paper laid in
them. Each room has one lit object, either a Mac's screen with the real notch on it, or Blob.

Three rules hold everything together:

1. **The notch is always on a lit screen.** The notch is black, so it disappears on a black page.
   Every screen on the site has a pale grey wallpaper, which makes the black notch the darkest
   thing in view. (Earlier versions put it on dark screens, and the product was hard to see.)
2. **The first screen is the pitch.** Headline, one sentence, both downloads, and the notch
   already at work underneath. Nothing has to be scrolled to before you know what Blob is.
3. **Blob is the only thing that wanders.** One character travels the page on the app's springs,
   perching on screens and headlines and taking each section's mood. Everything else stays put.

## Colour

Monochrome. Two rooms, set by tokens (`:root` is the black room, `.paper` flips them):

| | Black room | Paper |
|---|---|---|
| Background | `#000` | `#f5f5f7` |
| Ink | `#f5f5f7` | `#0a0a0b` |
| Secondary ink | `#a1a1a6` | `#48484d` |
| Tertiary ink | `#86868b` | `#6e6e73` |
| Hairline | `#232326` | `#d9d9de` |

Blob is one grey, `#949498`, everywhere. Screens use a soft grey wallpaper; windows on them are
dark. There is no accent colour: emphasis comes from the italic serif and from white-on-black
buttons.

## Type

- **Geist**, weights 400–600, for everything.
- **Instrument Serif italic** for the one accent phrase in a headline (*Let go.*, *a word.*),
  and for what Blob hears.
- **Geist Mono** for chapter labels and file sizes.

Scale: display 116 / h2 88 / h3 28 / lead 22 / body 18 / small 15 / label 12. Headlines are set
tight (−0.05em) and balanced.

## Layout

- A 1280 px column with fluid margins. Paper sheets are inset from the window edge and have
  large rounded corners, so they read as objects in the room.
- The navigation is the site's own notch: a black shape hanging from the top of the window. On
  the black rooms only its contents show; on paper it is a notch.
- Sections: hero and live demo → a day with Blob (pinned, five scenes) → moods (paper) →
  features (a bento of small screens) → privacy (paper) → downloads → footer.

## Motion

Everything that moves uses the Mac app's springs (`src/lib/spring.ts`), either solved per frame or
baked into `linear()` easings. Only `transform`, `opacity` and the notch's `clip-path` animate.

- The notch: the real state machine, wings, peek and panel, at the app's timings.
- Blob: the app's moods, ported number for number (`src/lib/mood.ts`).
- Scroll: headings and tiles arrive once; the scenes are pinned and scroll picks the scene; the
  mood's name drifts behind Blob; Blob travels between perches.
- With reduced motion, everything is simply in place and Blob only blinks.

## The screens

A screen is a close-up of the top of a Mac's display, drawn in Mac points and scaled as one
piece (`useScreenFit`), so the notch, menu bar and windows keep their real proportions at any
size. On a phone the closed notch is drawn larger, and it zooms out when it opens.

What Blob "hears" is shown as a caption under the notch. It is an annotation for the page, not
part of the app, and it is labelled "You say".

## Honesty

- Download buttons exist only for builds that are actually published (`src/lib/releases.ts`).
- The first-launch steps say plainly that the Mac build isn't notarized and that Windows may
  block it.
- Features that aren't on Windows yet are listed as Mac-only by omission in the Windows card.
- The demos are scripted. A request the page doesn't know gets an honest answer: this is a web
  page, so it can't touch your computer.
