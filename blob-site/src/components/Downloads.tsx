"use client";

import { useEffect, useState } from "react";
import type { Release } from "@/lib/releases";

/**
 * The two download buttons. The one for the computer you're on is the filled one
 * (Mac until we know better).
 */
export function Downloads({ mac, windows, megabytes }: { mac: Release | null; windows: Release | null; megabytes: { mac: string; windows: string } }) {
  const [onWindows, setOnWindows] = useState(false);
  useEffect(() => {
    setOnWindows(/Win/i.test(navigator.userAgent) && !/Phone/i.test(navigator.userAgent));
  }, []);
  if (!mac && !windows) {
    return (
      <a className="btn primary" href="#get">Get Blob</a>
    );
  }
  const macButton = mac && (
    <a key="mac" className={!onWindows || !windows ? "btn primary" : "btn"} href={mac.url} download>
      Download for Mac <span className="btn-meta">{megabytes.mac}</span>
    </a>
  );
  const winButton = windows && (
    <a key="win" className={onWindows || !mac ? "btn primary" : "btn"} href={windows.url} download>
      Download for Windows <span className="btn-meta">{megabytes.windows}</span>
    </a>
  );
  return <>{onWindows ? [winButton, macButton] : [macButton, winButton]}</>;
}
