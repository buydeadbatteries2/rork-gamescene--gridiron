import { Smartphone } from "lucide-react";

import { Logo, Shield } from "./Logo";
import { CautionTape } from "./Props";

export const ComingSoon = () => (
  <section id="coming-soon" className="relative isolate scroll-mt-20 overflow-hidden">
    <div className="overflow-hidden py-5">
      <CautionTape className="-ml-[5%] w-[110%]" rotate={1}>
        Truth lives on the field
      </CautionTape>
    </div>

    <div className="relative isolate py-24 sm:py-32">
      <div className="absolute inset-0 -z-10">
        <img src="/images/stadium_night.jpg" alt="" className="h-full w-full object-cover opacity-80" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(30,20,13,0.35)_0%,rgba(30,20,13,0.85)_60%,#1E140D_100%)]" />
      </div>

      <div className="mx-auto flex max-w-3xl flex-col items-center px-4 text-center sm:px-6">
        <Shield className="h-28 w-auto drop-shadow-[0_10px_30px_rgba(216,178,102,0.45)] sm:h-36" />
        <p className="kicker mt-8">GameScene: Gridiron</p>
        <h2 className="mt-4 text-[3.1rem] font-black leading-[0.88] text-shadow-deep sm:text-7xl lg:text-8xl">
          <span className="block text-cream">Truth lives</span>
          <span className="headline-gold block">on the field</span>
        </h2>
        <p className="mt-6 max-w-xl text-lg leading-relaxed text-cream/85">
          The case is almost ready. GameScene: Gridiron is coming soon to iPhone.
        </p>
        <div className="btn-gold mt-10 cursor-default" role="note">
          <Smartphone className="h-5 w-5" strokeWidth={2.5} />
          Coming soon to iPhone
        </div>
      </div>
    </div>
  </section>
);

export const Footer = () => (
  <footer className="border-t border-gold/20 bg-leather">
    <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-6 px-4 py-10 sm:flex-row sm:px-6 lg:px-8">
      <Logo />
      <p className="font-stamp text-sm text-cream/55">Same game, different answers.</p>
      <p className="text-xs text-cream/45">© {new Date().getFullYear()} GameScene: Gridiron</p>
    </div>
  </footer>
);
