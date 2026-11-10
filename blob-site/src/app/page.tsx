import { Suspense } from "react";
import { Nav, PageLife } from "@/components/Chrome";
import { BlobActor } from "@/components/BlobActor";
import { Hero } from "@/components/Hero";
import { Scenes } from "@/components/Scenes";
import { Moods } from "@/components/Moods";
import { Features } from "@/components/Features";
import { Footer, GetIt, Privacy } from "@/components/Closing";

// The hero is plain HTML at the top of the document, so the first paint is the real first screen.
// Sections below it sit in Suspense boundaries: each hydrates in its own short task, and React
// may send a large one just after the shell (it is below the fold, so nothing visible moves).
export default function Home() {
  return (
    <>
      <a className="skip" href="#main">Skip to content</a>
      <Nav />
      <PageLife />
      <main id="main">
        <Hero />
        <Suspense><Scenes /></Suspense>
        <Suspense><Moods /></Suspense>
        <Suspense><Features /></Suspense>
        <Privacy />
        <GetIt />
      </main>
      <Footer />
      <Suspense><BlobActor /></Suspense>
    </>
  );
}
