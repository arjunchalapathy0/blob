import { Eyebrow } from "./Chrome";
import { AmbientVideo } from "./AmbientVideo";
import { site } from "@/lib/site";

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
          {site.downloadUrl ? (
            <p className="body">Download it, drag it to Applications, and hold right ⌥.</p>
          ) : (
            <p className="body">
              There’s no download yet. Blob is built from its source: clone it, run one script, press Run in Xcode.
              It takes about five minutes, most of it Xcode.
            </p>
          )}
          <pre className="cmd" aria-label="Build steps"><code>{`./scripts/bootstrap.sh\nopen Blob.xcodeproj`}</code></pre>
          <p className="links">
            {site.downloadUrl && (
              <a className="button primary" href={site.downloadUrl}>Download Blob</a>
            )}
            <a className={site.downloadUrl ? "button" : "button primary"} href={site.sourceUrl}>Read the code</a>
          </p>
          <p className="fine">The repository is private for now, so the code is open to people who’ve been invited.</p>
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
