"use client";

import { useEffect, useState } from "react";
import type { Release } from "@/lib/releases";

type Platform = "mac" | "windows" | "linux";
type Item = { platform: Platform; label: string; release: Release; size: string };

/** Which computer this page is open on, as far as the browser says (Mac until we know better). */
function detect(): Platform {
  const ua = navigator.userAgent;
  if (/Android|iPhone|iPad/i.test(ua)) return "mac";
  if (/Win/i.test(ua)) return "windows";
  if (/Linux|X11|CrOS/i.test(ua)) return "linux";
  return "mac";
}

/**
 * One download button per published build. The one for the computer you're on goes first and is filled;
 * on the others it's the Mac.
 */
export function Downloads({ mac, windows, linux, sizes }: {
  mac: Release | null; windows: Release | null; linux: Release | null;
  sizes: Record<Platform, string>;
}) {
  const [here, setHere] = useState<Platform>("mac");
  useEffect(() => setHere(detect()), []);

  const items: Item[] = [];
  if (mac) items.push({ platform: "mac", label: "Download for Mac", release: mac, size: sizes.mac });
  if (windows) items.push({ platform: "windows", label: "Download for Windows", release: windows, size: sizes.windows });
  if (linux) items.push({ platform: "linux", label: "Download for Linux", release: linux, size: sizes.linux });
  if (items.length === 0) return <a className="btn primary" href="#get">Get Blob</a>;

  const first = items.find((i) => i.platform === here) ?? items[0];
  const ordered = [first, ...items.filter((i) => i !== first)];
  return (
    <>
      {ordered.map((item) => (
        <a
          key={item.platform}
          className={item === first ? "btn primary" : "btn"}
          // On Linux the button goes to the one-line install, which is easier than a download.
          href={item.platform === "linux" ? "#get-linux" : item.release.url}
          download={item.platform === "linux" ? undefined : true}
        >
          {item.label} <span className="btn-meta">{item.size}</span>
        </a>
      ))}
    </>
  );
}
