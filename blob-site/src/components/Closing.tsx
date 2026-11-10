import { AmbientVideo } from "./AmbientVideo";
import { Eyebrow } from "./Chrome";
import { site } from "@/lib/site";
import { megabytes, releases } from "@/lib/releases";

export function Privacy() {
  return (
    <section id="privacy" className="section paper privacy" aria-labelledby="privacy-title">
      <div className="wrap">
        <header className="section-head">
          <Eyebrow n="04">Privacy</Eyebrow>
          <h2 id="privacy-title" className="h2" data-reveal="">
            <span className="blob-anchor" data-blob="sit" data-blob-size="92" data-blob-x="0.72" data-blob-mood="curious" />
            What it sees, and <em>what it needs.</em>
          </h2>
        </header>
        <div className="facts">
          <div data-reveal="">
            <h3 className="h3">What it sees</h3>
            <ul>
              <li><strong>Your voice stays on your computer.</strong> Whisper turns it into text there. The model downloads once, about 150 MB, and works offline after that.</li>
              <li><strong>Your screen, only when you ask.</strong> One screenshot when you ask about it, or when the thing you asked for needs a look. Blob isn’t in it.</li>
              <li><strong>It asks first.</strong> Before deleting, sending or buying anything, Blob says what it would do and waits. It never uses sudo or admin rights, and doesn’t touch passwords.</li>
              <li><strong>Passwords skip the clipboard.</strong> Copies from password managers never reach the clipboard history.</li>
            </ul>
          </div>
          <div data-reveal="" style={{ "--d": 2 } as React.CSSProperties}>
            <h3 className="h3">What it needs</h3>
            <ul>
              <li><strong>A Mac or a PC.</strong> macOS 14 or later on Apple silicon or Intel, or Windows 10 or 11.</li>
              <li><strong>Claude Code.</strong> Installed and signed in. Blob does things through it, on your own Claude subscription.</li>
              <li><strong>Accessibility access on the Mac.</strong> For the ⌥ key, and for clicking around in apps.</li>
              <li><strong>A notch is the nicest home.</strong> On other screens, and on Windows, Blob draws its own.</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}

export function GetIt() {
  const { mac, windows } = releases;
  return (
    <section id="get" className="section get" aria-labelledby="get-title">
      <AmbientVideo className="get-light" />
      <div className="wrap">
        <Eyebrow n="05">Get Blob</Eyebrow>
        <h2 id="get-title" className="display get-title">
          <span className="blob-anchor" data-blob="sit" data-blob-size="150" data-blob-x="0.78" data-blob-mood="happy" data-blob-priority="200" />
          Move Blob <em>in.</em>
        </h2>

        <div className="platforms">
          <article className="platform" data-reveal="">
            <h3 className="h3">Mac</h3>
            <p className="small">macOS 14 or later. Apple silicon or Intel.</p>
            {mac ? (
              <>
                <a className="btn primary" href={mac.url} download>
                  Download for Mac <span className="btn-meta">{megabytes(mac.bytes)}</span>
                </a>
                <p className="fine">Version {mac.version}. Updates itself from Settings.</p>
                <div className="platform-foot">
                  <details className="first-open">
                    <summary className="link">Opening it the first time</summary>
                    <ol>
                      <li>Unzip, drag Blob to Applications, and open it.</li>
                      <li>Blob isn’t notarized by Apple yet, so macOS stops it once. Open System Settings → Privacy &amp; Security, scroll down, and click Open Anyway.</li>
                      <li>Hold right ⌥ and say something.</li>
                    </ol>
                  </details>
                </div>
              </>
            ) : (
              <>
                <p className="body">There’s no download yet. Clone it, run one script, press Run in Xcode.</p>
                <pre className="cmd" aria-label="Build steps"><code>{`./scripts/bootstrap.sh\nopen Blob.xcodeproj`}</code></pre>
              </>
            )}
          </article>

          <article className="platform" data-reveal="" style={{ "--d": 1 } as React.CSSProperties}>
            <h3 className="h3">Windows</h3>
            <p className="small">Windows 10 or 11. Blob lives in a pill at the top of your screen.</p>
            {windows ? (
              <>
                <a className="btn" href={windows.url} download>
                  Download for Windows <span className="btn-meta">{megabytes(windows.bytes)}</span>
                </a>
                <p className="fine">Version {windows.version}. Ask, Now Playing, timers, clipboard and Claude Code so far.</p>
                <div className="platform-foot">
                  <details className="first-open">
                    <summary className="link">Opening it the first time</summary>
                    <ol>
                      <li>Unzip and run Blob.exe. If SmartScreen doesn’t recognise it, click More info → Run anyway.</li>
                      <li>If Windows asks for the .NET 8 Desktop Runtime, click Yes. It’s free, from Microsoft.</li>
                      <li>If Smart App Control is on, Windows blocks apps it doesn’t know yet, and Blob is one of them for now.</li>
                    </ol>
                  </details>
                </div>
              </>
            ) : (
              <p className="body">Not out yet.</p>
            )}
          </article>

          <article className="platform" data-reveal="" style={{ "--d": 2 } as React.CSSProperties}>
            <h3 className="h3">iPhone</h3>
            <p className="small">A companion to the Mac app.</p>
            <p className="body">
              Timers and your next meeting in the Dynamic Island and on the Lock Screen. Pair it with your Mac using a
              six-digit code on the same Wi-Fi, and watch Claude work from the couch.
            </p>
            <div className="platform-foot">
              <p className="fine">Not on the App Store yet. Today it’s built from the source.</p>
            </div>
          </article>
        </div>
      </div>
    </section>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="blob-anchor footer-anchor" data-blob="sit" data-blob-size="64" data-blob-x="0.5" data-blob-mood="sleepy" data-blob-priority="600" />
      <div className="wrap footer-row">
        <p><span className="footer-brand">Blob</span>It lives in the notch.</p>
        <p className="footer-links">
          <a className="link" href="#get">Download</a>
          <a className="link" href="#privacy">Privacy</a>
          <a className="link" href={site.sourceUrl}>Source on GitHub</a>
        </p>
        <p className="fine">Not affiliated with Apple or Microsoft. MacBook, macOS and Windows are trademarks of their owners.</p>
      </div>
    </footer>
  );
}
