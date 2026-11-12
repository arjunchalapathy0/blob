import fs from "node:fs";
import path from "node:path";

/**
 * What's actually downloadable, read at build time from files the release workflows publish:
 *   public/version.json + public/Blob.zip                 (Mac, .github/workflows/mac-release.yml)
 *   public/windows/version.json + public/windows/Blob-Windows.zip (Windows, .github/workflows/windows-release.yml)
 *   public/linux/version.json + public/linux/Blob-Linux-*.tar.gz  (Linux, .github/workflows/linux-release.yml)
 * A platform with no published build simply doesn't get a download button.
 */
export type Release = { version: string; build: number; url: string; bytes?: number; date?: string };

function read(rel: string): Release | null {
  try {
    const file = path.join(process.cwd(), "public", rel);
    const r = JSON.parse(fs.readFileSync(file, "utf8")) as Release;
    const zip = path.join(process.cwd(), "public", r.url.replace(/^\//, ""));
    return fs.existsSync(zip) ? r : null;
  } catch {
    return null;
  }
}

export const releases = {
  mac: read("version.json"),
  windows: read("windows/version.json"),
  linux: read("linux/version.json"),
};

/** The one-line Linux install, shown on the site once a Linux build is published. */
export const linuxInstall = "curl -fsSL https://blobnotch.app/linux/install.sh | sh";

/** "Mac, Windows and Linux", for whichever builds are published. */
export function platformList(): string {
  const names = [releases.mac || !releases.windows ? "Mac" : null, releases.windows ? "Windows" : null, releases.linux ? "Linux" : null]
    .filter((n): n is string => !!n);
  return names.length > 1 ? `${names.slice(0, -1).join(", ")} and ${names.at(-1)}` : names[0];
}

export function megabytes(bytes?: number) {
  return bytes ? `${Math.max(1, Math.round(bytes / 1e6))} MB` : "";
}
