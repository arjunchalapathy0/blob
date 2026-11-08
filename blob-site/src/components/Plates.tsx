import { Eyebrow } from "./Chrome";

/**
 * An interlude between chapters: three art-directed stills of Blob, lit like a night scene.
 * They're renders of the real character (same body, same eyes), not photographs.
 */
const PLATES = [
  { id: "notch", w: 1600, h: 800, srcs: [800, 1600], alt: "Blob peeking out from under a MacBook’s notch, lit by the screen", caption: "At home, in the notch.", cls: "plate-wide" },
  { id: "key", w: 1600, h: 1000, srcs: [800, 1600], alt: "Blob sitting on the right Option key of a dark keyboard", caption: "Right ⌥: hold it, and Blob listens.", cls: "plate-key" },
  { id: "sleep", w: 1200, h: 1000, srcs: [1200], alt: "Blob asleep, eyes shut, in a pool of soft light", caption: "Left alone for ten minutes.", cls: "plate-sleep" },
];

export function Plates() {
  return (
    <section className="section plates" aria-labelledby="plates-title">
      <div className="wrap">
        <div className="plates-head">
          <Eyebrow n="04">Interlude</Eyebrow>
          <h2 id="plates-title" className="h2" data-reveal="">
            A character, <em>not a cursor.</em>
          </h2>
        </div>
        <div className="plates-grid">
          {PLATES.map((p, i) => (
            <figure key={p.id} className={`plate ${p.cls}`} data-reveal="" style={{ "--d": i } as React.CSSProperties}>
              <div className="plate-frame">
                <img
                  src={`/media/${p.id}-${p.srcs[p.srcs.length - 1]}.webp`}
                  srcSet={p.srcs.map((w) => `/media/${p.id}-${w}.webp ${w}w`).join(", ")}
                  sizes={p.cls === "plate-wide" ? "(max-width: 900px) 100vw, 1312px" : "(max-width: 900px) 100vw, 640px"}
                  width={p.w}
                  height={p.h}
                  alt={p.alt}
                  loading="lazy"
                  decoding="async"
                />
              </div>
              <figcaption><span>{String(i + 1).padStart(2, "0")}</span>{p.caption}</figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}
