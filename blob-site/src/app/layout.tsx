import type { Metadata, Viewport } from "next";
import { Bricolage_Grotesque, Newsreader } from "next/font/google";
import { site } from "@/lib/site";
import "./globals.css";

const display = Bricolage_Grotesque({
  subsets: ["latin"],
  axes: ["wdth"],
  display: "swap",
  variable: "--font-display",
});

const text = Newsreader({
  subsets: ["latin"],
  // Preloaded, but never swapped in late: on a slow first visit the metric-matched fallback stays,
  // so the copy never shifts. Every later visit has it cached.
  display: "optional",
  variable: "--font-text",
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
    { media: "(prefers-color-scheme: light)", color: "#C9CACD" },
    { media: "(prefers-color-scheme: dark)", color: "#17181A" },
  ],
};

// Applies a saved appearance before first paint, so there is no flash.
const themeScript = `try{var t=localStorage.getItem("theme");if(t==="light"||t==="dark")document.documentElement.dataset.theme=t}catch(e){}`;

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${display.variable} ${text.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body id="top">{children}</body>
    </html>
  );
}
