import { useState } from "react";
import { Award, CircleUserRound, Eye, Lightbulb, Medal, ShoppingBag } from "lucide-react";

import { cn } from "@/lib/utils";

import { Pin, Polaroid, SectionHeading } from "./Props";

const redactions = ["w-[62%]", "w-[48%]", "w-[70%]", "w-[40%]"];

const RankedCard = () => (
  <article className="leather-panel relative flex h-full flex-col rounded-3xl p-6 sm:p-8">
    <div className="flex items-center justify-between gap-4">
      <span className="label-strip !bg-gold !text-ink">Ranked</span>
      <Medal className="h-7 w-7 text-gold" />
    </div>
    <h3 className="headline-gold mt-5 text-4xl font-black leading-[0.95] sm:text-5xl">Ranked play and a leaderboard</h3>
    <p className="mt-3 max-w-md text-[0.95rem] leading-relaxed text-cream/75">
      Put your detective work up against other players and see where your name lands on the board.
    </p>

    <div className="paper mt-7 rounded-xl p-4 sm:p-5">
      <div className="flex items-center justify-between border-b-2 border-ink/20 pb-2 font-slab text-xs font-extrabold uppercase tracking-[0.24em] text-ink/70">
        <span>Leaderboard</span>
        <span className="stamp rotate-[-4deg] px-2 py-0 text-[0.6rem]">Classified</span>
      </div>
      <ul className="mt-2 divide-y divide-ink/10">
        {redactions.map((w, i) => (
          <li key={w} className="flex items-center gap-4 py-2.5">
            <span className="w-6 font-slab text-xl font-black text-ink/80">{i + 1}</span>
            <span className={cn("h-3.5 rounded-[2px] bg-ink/85", w)} aria-hidden="true" />
            <span className="sr-only">Redacted player</span>
          </li>
        ))}
        <li className="-mx-2 flex items-center gap-4 rounded-md bg-tape/70 px-2 py-2.5">
          <span className="w-6 font-slab text-xl font-black text-ink">?</span>
          <span className="font-slab text-lg font-black uppercase tracking-[0.12em] text-ink">Your team</span>
        </li>
      </ul>
    </div>
  </article>
);

const TrophyCard = () => (
  <article className="relative flex h-full flex-col overflow-hidden rounded-3xl border-2 border-gold/60 bg-gradient-to-b from-[#4a3220] to-[#1e140d] p-6 sm:p-8">
    <div className="pointer-events-none absolute -right-10 -top-10 h-40 w-40 rounded-full bg-gold/20 blur-3xl" />
    <Award className="h-10 w-10 text-gold" />
    <h3 className="mt-5 text-4xl font-black leading-[0.95] text-cream">Trophy Room</h3>
    <p className="mt-3 text-[0.95rem] leading-relaxed text-cream/75">
      Every achievement you earn ends up on the wall. Your career, kept on display.
    </p>
    <div className="mt-auto pt-7">
      <div className="rounded-lg bg-gradient-to-b from-[#f3d995] via-[#d8b266] to-[#9a7533] px-4 py-3 text-center font-slab text-sm font-black uppercase tracking-[0.3em] text-ink shadow-[inset_0_1px_0_rgba(255,255,255,0.5),0_8px_16px_rgba(0,0,0,0.5)]">
        Achievements
      </div>
    </div>
  </article>
);

const ShopCard = () => (
  <article className="folder flex h-full flex-col p-6 sm:p-7">
    <div className="folder-tab">Shop</div>
    <div className="flex items-start justify-between gap-4">
      <div>
        <ShoppingBag className="h-8 w-8 text-ink/80" />
        <h3 className="mt-4 text-4xl font-black leading-[0.95] text-ink">Game Balls and hints</h3>
      </div>
    </div>
    <p className="mt-3 font-type text-[0.95rem] leading-relaxed text-ink/75">
      Visit the Shop for Game Balls and hints when a case needs a push.
    </p>
    <div className="mt-auto flex items-end justify-between gap-3 pt-5">
      <span className="inline-flex items-center gap-1.5 rounded-full bg-ink px-3 py-1.5 font-slab text-xs font-extrabold uppercase tracking-[0.18em] text-manila">
        <Lightbulb className="h-3.5 w-3.5 text-tape" /> Hints
      </span>
      <Polaroid
        src="/images/photo_ball.jpg"
        alt="A football on a white yard line at night"
        caption="Game Ball"
        rotate={5}
        fastener="pin"
        className="w-[48%] max-w-[170px]"
      />
    </div>
  </article>
);

const AccountCard = () => (
  <article className="note-paper relative flex h-full flex-col rounded-sm p-6 pt-9 sm:p-7 sm:pt-10">
    <Pin className="left-1/2 top-2.5 -translate-x-1/2" />
    <CircleUserRound className="h-8 w-8 text-ink/80" />
    <h3 className="mt-4 text-4xl font-black leading-[0.95] text-ink">Your file stays with you</h3>
    <p className="mt-3 font-type text-[0.95rem] leading-[26px] text-ink/80">
      Sign in to save your team and your season progress to your account.
    </p>
    <span className="stamp mt-auto self-end rotate-[-6deg] text-base">Saved</span>
  </article>
);

const AccessibilityCard = () => {
  const [large, setLarge] = useState(false);
  return (
    <article className="leather-panel flex h-full flex-col rounded-3xl p-6 sm:p-7">
      <div className="flex items-center justify-between gap-4">
        <Eye className="h-8 w-8 text-gold" />
        <div className="flex rounded-full border-2 border-gold/60 p-1" role="group" aria-label="Clue text size preview">
          {[
            { v: false, label: "Aa", cls: "text-sm" },
            { v: true, label: "Aa", cls: "text-xl" },
          ].map((o) => (
            <button
              key={String(o.v)}
              type="button"
              onClick={() => setLarge(o.v)}
              aria-pressed={large === o.v}
              aria-label={o.v ? "Larger clue text" : "Standard clue text"}
              className={cn(
                "flex h-9 w-11 items-center justify-center rounded-full font-slab font-black transition-colors",
                o.cls,
                large === o.v ? "bg-gold text-ink" : "text-gold hover:bg-gold/10",
              )}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>
      <h3 className="mt-4 text-4xl font-black leading-[0.95] text-cream">Accessibility options</h3>
      <p className="mt-3 text-[0.95rem] leading-relaxed text-cream/75">
        Options like larger clue text, so nobody misses a detail. Try the switch.
      </p>
      <div className="paper mt-auto rounded-lg px-4 py-3">
        <p
          className={cn(
            "font-type text-ink transition-all duration-300",
            large ? "text-xl leading-snug sm:text-2xl" : "text-sm leading-snug",
          )}
        >
          <span className="font-slab font-black text-stamp">Clue </span>
          He lined up wide, then disappeared.
        </p>
      </div>
    </article>
  );
};

export const ClubhouseSection = () => (
  <section id="clubhouse" className="relative scroll-mt-20 py-24 sm:py-32">
    <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <SectionHeading kicker="Off the field" title="The clubhouse">
        <p>Everything around the case: where you compete, what you've earned, and how you play.</p>
      </SectionHeading>

      <div className="mt-14 grid gap-x-6 gap-y-12 md:grid-cols-2 lg:grid-cols-6 lg:gap-y-10">
        <div className="md:col-span-2 lg:col-span-4">
          <RankedCard />
        </div>
        <div className="lg:col-span-2">
          <TrophyCard />
        </div>
        <div className="lg:col-span-2">
          <ShopCard />
        </div>
        <div className="lg:col-span-2">
          <AccountCard />
        </div>
        <div className="md:col-span-2 lg:col-span-2">
          <AccessibilityCard />
        </div>
      </div>
    </div>
  </section>
);
