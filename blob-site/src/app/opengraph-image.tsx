import { ImageResponse } from "next/og";

export const alt = "Blob: a grey character in a MacBook notch. Hold Option. Say it. Let go.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** The display face, as TrueType (what next/og can read), fetched at build time. */
async function displayFont(text: string): Promise<ArrayBuffer | null> {
  try {
    const css = await (
      await fetch(`https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:wdth,wght@75,800&text=${encodeURIComponent(text)}`)
    ).text();
    const url = css.match(/src: url\((.+?)\) format\('(?:truetype|opentype)'\)/)?.[1];
    return url ? await (await fetch(url)).arrayBuffer() : null;
  } catch {
    return null;
  }
}

export default async function OpengraphImage() {
  const font = await displayFont("Hold. Say it. Let go.option");
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          background: "#C9CACD",
          position: "relative",
        }}
      >
        <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 2, background: "#B7B8BC" }} />
        <div
          style={{
            width: 560,
            height: 300,
            background: "#000",
            borderBottomLeftRadius: 80,
            borderBottomRightRadius: 80,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <div
            style={{
              width: 168,
              height: 150,
              borderRadius: 54,
              background: "#949498",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: 36,
              paddingBottom: 14,
            }}
          >
            <div style={{ width: 20, height: 32, borderRadius: 10, background: "#000" }} />
            <div style={{ width: 20, height: 32, borderRadius: 10, background: "#000" }} />
          </div>
        </div>
        <div style={{ marginTop: 72, fontSize: 96, fontWeight: 800, letterSpacing: -4, color: "#232427", display: "flex", alignItems: "center", fontFamily: "Display" }}>
          <span style={{ marginRight: 18 }}>Hold</span>
          <span
            style={{
              display: "flex",
              alignItems: "flex-end",
              height: 80,
              padding: "0 14px 10px",
              borderRadius: 14,
              background: "#232427",
              color: "#C9CACD",
              fontSize: 26,
              letterSpacing: 0,
            }}
          >
            option
          </span>
          <span>.&nbsp;Say it. Let go.</span>
        </div>
      </div>
    ),
    { ...size, fonts: font ? [{ name: "Display", data: font, weight: 800, style: "normal" }] : [] },
  );
}
