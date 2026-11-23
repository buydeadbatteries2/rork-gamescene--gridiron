import { ArrowDown, Smartphone } from "lucide-react";

import { CautionTape, Pin, Polaroid } from "./Props";

const EvidenceStack = () => (
  <div className="relative mx-auto aspect-[1/1.02] w-full max-w-[560px]">
    {/* folder */}
    <div className="folder absolute left-[6%] top-[12%] h-[70%] w-[80%] rotate-[-3deg] p-[6%]">
      <div className="folder-tab">Case file</div>
      <div className="flex items-start justify-between gap-3">
        <span className="label-strip">Missing player</span>
      </div>
      <div className="mt-[7%] space-y-[4%] font-type text-[clamp(0.72rem,1.9vw,0.95rem)] leading-snug text-ink/85">
        <p>
          <span className="font-bold">Position:</span> on the field, not on the sheet
        </p>
        <p>
          <span className="font-bold">Profile:</span> one of four
        </p>
        <p>
          <span className="font-bold">Clues:</span> in the play
        </p>
        <div className="stitch !bg-[linear-gradient(90deg,rgba(36,23,13,0.35)_50%,transparent_50%)]" />
        <p className="font-stamp text-ink/70">Read the play. Trust the tape.</p>
      </div>
      <span
        className="stamp animate-stamp absolute bottom-[10%] right-[8%] text-[clamp(1rem,3.4vw,1.7rem)]"
        style={{ ["--r" as string]: "-12deg", animationDelay: "0.5s" }}
      >
        Unidentified
      </span>
    </div>

    <Polaroid
      src="/images/photo_runner.jpg"
      alt="A football player running with the ball under stadium lights"
      caption="Who had the ball?"
      rotate={7}
      className="absolute right-0 top-0 w-[42%]"
    />
    <Polaroid
      src="/images/photo_tunnel.jpg"
      alt="A player walking out of the stadium tunnel toward the lit field"
      caption="Last seen: the tunnel"
      rotate={-9}
      fastener="pin"
      className="absolute bottom-[2%] left-0 w-[38%]"
    />

    {/* pinned note */}
    <div className="note-paper absolute bottom-[8%] right-[3%] w-[44%] rotate-[4deg] px-4 pb-4 pt-6">
      <Pin className="left-1/2 top-1.5 -translate-x-1/2" />
      <p className="font-stamp text-[clamp(0.78rem,2vw,1rem)] leading-[26px] text-ink/85">
        The box score says one thing. The play says another.
      </p>
    </div>

    <CautionTape className="absolute -right-[12%] top-[62%] z-20 w-[70%]" rotate={-14}>
      Do not cross
    </CautionTape>
  </div>
);

export const Hero = () => (
  <section id="top" className="relative isolate overflow-hidden">
    <div className="absolute inset-0 -z-10">
      <img
        src="/images/stadium_night.jpg"
        alt=""
        className="h-full w-full object-cover object-center opacity-90"
        fetchPriority="high"
      />
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_70%_20%,transparent_0%,rgba(30,20,13,0.55)_55%,#1E140D_100%)]" />
      <div className="absolute inset-0 bg-gradient-to-b from-leather/30 via-leather/40 to-leather" />
      <div className="absolute inset-0 bg-gradient-to-r from-leather/90 via-leather/40 to-transparent" />
    </div>

    <div className="mx-auto grid max-w-7xl items-center gap-14 px-4 pb-20 pt-14 sm:px-6 sm:pt-20 lg:grid-cols-[1.05fr_1fr] lg:gap-10 lg:px-8 lg:pb-28 lg:pt-24">
      <div>
        <div className="flex flex-wrap items-center gap-3">
          <span className="stamp stamp-on-dark rotate-[-3deg] text-xs sm:text-sm">Case open</span>
          <span className="kicker">A football mystery for iPhone</span>
        </div>

        <h1 className="mt-6 font-black leading-[0.86] text-shadow-deep">
          <span className="block text-[3.4rem] text-cream sm:text-[5.2rem] lg:text-[6.4rem]">Same game,</span>
          <span className="headline-gold block text-[3.4rem] sm:text-[5.2rem] lg:text-[6.4rem]">different answers</span>
        </h1>

        <p className="mt-7 max-w-xl text-lg leading-relaxed text-cream/85 sm:text-xl">
          Every play leaves clues. In GameScene: Gridiron you read them, work out which players are missing, and put
          the right ones back on the field.
        </p>

        <div className="mt-10 flex flex-col items-start gap-5 sm:flex-row sm:items-center">
          <a href="#coming-soon" className="btn-gold">
            <Smartphone className="h-5 w-5" strokeWidth={2.5} />
            Coming soon to iPhone
          </a>
          <a href="#case" className="btn-brass">
            Open the case file
            <ArrowDown className="h-4 w-4" />
          </a>
        </div>
      </div>

      <EvidenceStack />
    </div>
  </section>
);
