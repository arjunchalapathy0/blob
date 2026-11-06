import { Suspense } from "react";
import { Notch } from "@/components/Notch";
import { MenuBar, PageLife } from "@/components/Chrome";
import { Hero } from "@/components/Hero";
import { Scenes } from "@/components/Scenes";
import { Moods } from "@/components/Moods";
import { Everything } from "@/components/Everything";
import { Phone } from "@/components/Phone";
import { Footer, GetIt, Privacy } from "@/components/Closing";

// Each Suspense boundary hydrates on its own, in its own short task, instead of the whole page at once.
export default function Home() {
  return (
    <>
      <a className="skip" href="#main">Skip to content</a>
      <MenuBar />
      <Suspense>
        <Notch />
      </Suspense>
      <PageLife />
      <main id="main">
        <Suspense>
          <Hero />
        </Suspense>
        <Suspense>
          <Scenes />
        </Suspense>
        <Suspense>
          <Moods />
        </Suspense>
        <Suspense>
          <Everything />
        </Suspense>
        <Privacy />
        <Suspense>
          <Phone />
        </Suspense>
        <GetIt />
      </main>
      <Footer />
    </>
  );
}
