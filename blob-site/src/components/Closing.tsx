import { Eyebrow } from "./Chrome";
import { AmbientVideo } from "./AmbientVideo";
import { site } from "@/lib/site";
import { megabytes, releases } from "@/lib/releases";

export function Privacy() {
  return (
    <section id="privacy" className="section privacy" aria-labelledby="privacy-title">
      <div className="wrap privacy-grid">
        <div className="privacy-head">
          <Eyebrow n="06">Privacy</Eyebrow>
          <h2 id="privacy-title" className="h2" data-reveal="">
          <span className="blob-anchor" data-blob="sit" data-blob-size="90" data-blob-x="0.2" data-blob-mood="curious" />
          What it sees, and <em>what it needs.</em>
        </h2>
        </div>
        <div className="rows" data-reveal="">
          <h3 className="rows-title">What it sees</h3>
          <ul>
            <li>Your voice becomes text on your Mac, with Whisper. The model downloads once, about 150 MB, and works offline after that.</li>
            <li>It looks at your screen when you ask about it, or when the thing you asked for needs a look. One screenshot, without Blob in it.</li>
            <li>It asks before deleting, sending or buying anything. It never uses sudo and doesn’t touch passwords.</li>
            <li>Copies from password managers never reach the clipboard history.</li>
          </ul>
        </div>
        <div className="rows" data-reveal="" style={{ "--d": 2 } as React.CSSProperties}>
          <h3 className="rows-title">What it needs</h3>
          <ul>
            <li>macOS 14 or later, on Apple silicon or Intel.</li>
            <li>Claude Code, installed and signed in. Blob does things through it, on your own Claude subscription.</li>
            <li>Accessibility access, for the ⌥ key and for clicking around in apps.</li>
            <li>A MacBook with a notch is the nicest home. On other screens Blob draws its own.</li>
          </ul>
        </div>
      </div>
    </section>
  );
}

export function GetIt() {
  const { mac, windows } = releases;
  return (
    <section id="get" className="section get" data-mood="curious" aria-labelledby="get-title">
      <AmbientVideo className="get-light" />
      <div className="wrap get-grid">
        <div className="get-head">
        <Eyebrow n="08">Get Blob</Eyebrow>
        <h2 id="get-title" className="display get-title">
          <span className="blob-anchor" data-blob="sit" data-blob-size="150" data-blob-x="0.78" data-blob-mood="happy" />
          Move Blob <em>in.</em>
        </h2>
        </div>
        <div className="get-copy" data-reveal="">
          {mac || windows ? (
            <>
              <p className="body">Download it, open it, and hold right ⌥ (right Alt on Windows).</p>
              <p className="links">
                {mac && (
                  <a className="button primary" href={mac.url} download>
                    Download for Mac <span className="button-meta">{mac.version} · {megabytes(mac.bytes)}</span>
                  </a>
                )}
                {windows && (
                  <a className={mac ? "button" : "button primary"} href={windows.url} download>
                    Download for Windows <span className="button-meta">{windows.version} · {megabytes(windows.bytes)}</span>
                  </a>
                )}
              </p>
              <details className="first-open">
                <summary className="link">First time opening it</summary>
                {mac && (
                  <p className="fine">
                    <strong>Mac</strong> (macOS 14 or later): unzip, drag Blob to Applications and open it. Blob isn’t
                    notarized by Apple yet, so macOS stops it the first time. Open System Settings → Privacy &amp; Security,
                    scroll down and click Open Anyway. After that, Blob updates itself from Settings.
                  </p>
                )}
                {windows && (
                  <p className="fine">
                    <strong>Windows</strong> (Windows 10 or 11): unzip and run Blob.exe. Windows SmartScreen may say it
                    doesn’t recognise the app: click More info → Run anyway. If Windows asks for the .NET 8 Desktop
                    Runtime, click Yes to install it (free, from Microsoft). Blob lives in a small pill at the top of
                    your screen, since most PCs don’t have a notch.
                  </p>
                )}
              </details>
            </>
          ) : (
            <>
              <p className="body">
                There’s no download yet. Blob is built from its source: clone it, run one script, press Run in Xcode.
                It takes about five minutes, most of it Xcode.
              </p>
              <pre className="cmd" aria-label="Build steps"><code>{`./scripts/bootstrap.sh\nopen Blob.xcodeproj`}</code></pre>
            </>
          )}
          <p className="links">
            <a className="button" href={site.sourceUrl}>Read the code</a>
          </p>
          <p className="fine">The code is private for now, open to people who’ve been invited.</p>
        </div>
      </div>
    </section>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="blob-anchor footer-anchor" data-blob="sit" data-blob-size="70" data-blob-x="0.5" data-blob-mood="sleepy" data-blob-priority="600" />
      <div className="wrap footer-row">
        <p><span className="wordmark">Blob</span> It lives in the notch.</p>
        <p className="fine">Not affiliated with Apple. MacBook and macOS are trademarks of Apple Inc.</p>
      </div>
    </footer>
  );
}
