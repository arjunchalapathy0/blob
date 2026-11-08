/**
 * Scripted requests for the demos. Step labels are the app's real ones (ClaudeCLI.stepLabel);
 * a Bash step with a description shows the description, which Claude writes, so those read
 * like plain instructions. Safety behaviour (asking before deleting) is the app's real rule.
 */
export type Step = { label: string; ms: number; outcome?: string };

export type Script = {
  id: string;
  /** What you'd say. Whisper's transcript is shown as these words. */
  spoken: string;
  steps: Step[];
  reply: string;
  /** Fired when the reply lands. */
  outcome?: string;
  /** A suggested follow-up that continues the same conversation. */
  followUp?: { label: string; script: Script };
  /** After the notice, the wings settle into this (e.g. music keeps playing). */
  after?: "music";
};

const trashDone: Script = {
  id: "trash-yes",
  spoken: "Yes, do it",
  steps: [{ label: "Controlling an app", ms: 1100, outcome: "trash-empty" }],
  reply: "Emptied the trash.",
};

export const HERO_REQUESTS: Script[] = [
  {
    id: "anime",
    spoken: "Play episode 3 of Attack on Titan",
    steps: [
      { label: "Searching the web", ms: 1200 },
      { label: "Open the episode in Safari", ms: 1100, outcome: "player-open" },
      { label: "Controlling an app", ms: 1000, outcome: "player-play" },
    ],
    reply: "Episode 3 is playing in Safari, full screen.",
  },
  {
    id: "calm",
    spoken: "Put on something calm",
    steps: [
      { label: "Thinking", ms: 600 },
      { label: "Controlling an app", ms: 1300, outcome: "music-play" },
    ],
    reply: "Playing a calm mix in Music.",
    after: "music",
  },
  {
    id: "morning",
    spoken: "Run my Morning shortcut",
    steps: [{ label: "Running a shortcut", ms: 1500, outcome: "shortcut" }],
    reply: "Ran Morning. Focus is on and today’s calendar is open.",
  },
  {
    id: "error",
    spoken: "What does this error mean?",
    steps: [
      { label: "Looking at your screen", ms: 1500, outcome: "scan" },
      { label: "Thinking", ms: 700 },
    ],
    reply: "Something is already using port 3000. Quit it, or start this one with PORT=3001.",
    outcome: "explain",
  },
  {
    id: "trash",
    spoken: "Empty the trash",
    steps: [{ label: "Count what’s in the trash", ms: 1100 }],
    reply: "That deletes 214 items for good. Say yes and I’ll empty it.",
    followUp: { label: "Yes, do it", script: trashDone },
  },
];

/** Reply for anything typed that isn't one of the demos. Honest about being a web page. */
export const OFF_SCRIPT_REPLY =
  "This is a web page, so I can’t touch your computer from here. On your Mac, I’d just do it.";

export function matchRequest(text: string): Script | null {
  const t = text.toLowerCase();
  if (/(attack on titan|episode|anime|aot)/.test(t)) return HERO_REQUESTS[0];
  if (/(calm|music|play some|lofi|song)/.test(t)) return HERO_REQUESTS[1];
  if (/(shortcut|morning)/.test(t)) return HERO_REQUESTS[2];
  if (/(error|terminal|what does)/.test(t)) return HERO_REQUESTS[3];
  if (/(trash|empty)/.test(t)) return HERO_REQUESTS[4];
  return null;
}

/** Scroll scenes. */
export const SCENES = {
  focus: {
    id: "focus",
    spoken: "Put on something to focus to",
    steps: [{ label: "Controlling an app", ms: 1300, outcome: "music-play" }],
    reply: "Playing a focus mix in Music.",
    after: "music",
  } satisfies Script,
  see: {
    id: "see",
    spoken: "Why is my build failing?",
    steps: [
      { label: "Looking at your screen", ms: 1500, outcome: "scan" },
      { label: "Reading package.json", ms: 900 },
    ],
    reply: "react-dom is on 18 but react is on 19. Install matching versions and run it again.",
    outcome: "explain",
  } satisfies Script,
  shortcut: {
    id: "shortcut",
    spoken: "Start my day",
    steps: [
      { label: "Running a shortcut", ms: 1300, outcome: "shortcut" },
      { label: "Opening something", ms: 800 },
    ],
    reply: "Ran Morning and opened today’s calendar.",
  } satisfies Script,
  asks: {
    id: "asks",
    spoken: "Delete everything in Downloads",
    steps: [{ label: "Searching files", ms: 1200 }],
    reply: "That’s 1,284 files, gone for good. Want me to do it?",
    outcome: "ask",
  } satisfies Script,
};
