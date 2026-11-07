import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Instrument_Serif } from "next/font/google";
import { site } from "@/lib/site";
import "./globals.css";

const sans = Geist({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-sans",
});

// Only for the italic accent words in headlines.
const serif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: "italic",
  display: "swap",
  variable: "--font-serif",
});

const mono = Geist_Mono({
  subsets: ["latin"],
  display: "swap",
  preload: false,
  variable: "--font-mono",
});

export const metadata: Metadata = {
  metadataBase: new URL(site.siteUrl),
  title: "Blob — it lives in your notch, and does what you say",
  description:
    "Blob lives in your MacBook’s notch. Hold right Option, say what you want, and it does it on your Mac: opens apps, plays music, runs Shortcuts, reads your screen when you ask.",
  openGraph: {
    title: "Blob",
    description: "Hold ⌥. Say it. Let go. A notch for your MacBook that does what you say.",
    type: "website",
  },
  twitter: { card: "summary_large_image" },
};

export const viewport: Viewport = {
  themeColor: [
    { color: "#000000" },
  ],
};

// Applies a saved appearance before first paint, so there is no flash.
const themeScript = `document.documentElement.classList.add("js");try{var t=localStorage.getItem("theme");if(t==="light"||t==="dark")document.documentElement.dataset.theme=t}catch(e){}`;

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${sans.variable} ${serif.variable} ${mono.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body id="top">{children}</body>
    </html>
  );
}
