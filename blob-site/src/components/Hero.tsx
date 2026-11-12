import { Downloads } from "./Downloads";
import { HeroDemo } from "./HeroDemo";
import { megabytes, platformList, releases } from "@/lib/releases";

const i = (n: number) => ({ "--i": n }) as React.CSSProperties;

/** The first screen: what it is, how to get it, and the real notch doing its thing right below. */
export function Hero() {
  const { mac, windows, linux } = releases;
  const platforms = platformList();
  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="wrap hero-head">
        <p className="chip" style={i(0)}><i />Free for {platforms}</p>
        <h1 id="hero-title" className="display hero-title">
          <span className="line" style={i(1)}>
            Hold <span className="h-key"><span aria-hidden="true">⌥</span><span className="sr-only">right Option</span></span>.
          </span>{" "}
          <span className="line" style={i(2)}>Say it.</span>{" "}
          <span className="line" style={i(3)}><em>Let go.</em></span>
        </h1>
        <p className="lead" style={i(4)}>
          Blob lives in your MacBook’s notch. Hold right Option, say what you want, and it gets it done on your
          Mac: opens apps, plays music, runs Shortcuts, reads your screen when you ask.
        </p>
        <div className="hero-cta" style={i(5)}>
          <Downloads
            mac={mac}
            windows={windows}
            linux={linux}
            sizes={{ mac: megabytes(mac?.bytes), windows: megabytes(windows?.bytes), linux: megabytes(linux?.bytes) }}
          />
        </div>
        <p className="fine" style={i(6)}>
          Free. macOS 14 or later{windows ? ", Windows 10 or 11" : ""}{linux ? ", most Linux desktops and Chromebooks" : ""}. It acts through Claude Code, on
          your own Claude subscription.
        </p>
      </div>
      <HeroDemo />
    </section>
  );
}
