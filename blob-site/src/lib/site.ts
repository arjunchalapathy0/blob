/**
 * The few things the owner will want to change, in one place.
 */
export const site = {
  name: "Blob",
  /** Public URL of the deployed site (used for metadata and the share image). */
  siteUrl: "https://blobnotch.app",
  /** The source repository. It is private today, so this link works only for invited people. */
  sourceUrl: "https://github.com/arjunchalapathy0/blob",
  // Downloads come from src/lib/releases.ts, which reads what the release workflows published.
  /**
   * Real screen recordings of Blob, dropped into public/recordings/. Each entry renders a <video>
   * next to the matching scene. Leave empty to show only the recreations.
   * Example: { scene: "music", src: "/recordings/music.mp4", poster: "/recordings/music.jpg" }
   */
  recordings: [] as { scene: string; src: string; poster?: string }[],
} as const;
