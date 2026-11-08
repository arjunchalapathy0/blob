"use client";

import { forwardRef, useEffect, useRef } from "react";
import { reducedMotion } from "@/lib/ticker";

/**
 * The room's light: a quiet 10-second loop (dust drifting in a shaft of light from the notch).
 * About 50 KB. Plays only while on screen; with reduced motion it stays a still frame.
 */
export const AmbientVideo = forwardRef<HTMLDivElement, { className?: string }>(function AmbientVideo({ className }, ref) {
  const video = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    const v = video.current;
    if (!v) return;
    if (reducedMotion()) return;
    const io = new IntersectionObserver(([e]) => {
      if (e.isIntersecting) v.play().catch(() => {});
      else v.pause();
    });
    io.observe(v);
    return () => io.disconnect();
  }, []);
  return (
    <div ref={ref} className={className ? `ambient ${className}` : "ambient"} aria-hidden="true">
      <video ref={video} muted loop playsInline preload="metadata" poster="/media/room-poster.webp" tabIndex={-1}>
        <source src="/media/room.webm" type="video/webm" />
        <source src="/media/room.mp4" type="video/mp4" />
      </video>
    </div>
  );
});
