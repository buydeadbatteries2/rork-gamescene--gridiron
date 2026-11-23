import { CalendarDays, Gauge, Timer, Trophy, Swords } from "lucide-react";

import { SectionHeading } from "./Props";

const stops = [
  { icon: CalendarDays, title: "Weekly games", note: "A new game on the schedule every week of the season." },
  { icon: Timer, title: "Overtime", note: "Tied at the whistle? The case stays open a little longer." },
  { icon: Swords, title: "Playoffs", note: "Win enough and your team plays on." },
  { icon: Trophy, title: "Championship", note: "One last game. One last set of clues." },
];

export const SeasonSection = () => (
  <section id="season" className="relative isolate scroll-mt-20 overflow-hidden py-24 sm:py-32">
    <div className="absolute inset-0 -z-10">
      <img src="/images/stadium_night.jpg" alt="" className="h-full w-full scale-x-[-1] object-cover opacity-45" />
      <div className="absolute inset-0 bg-gradient-to-b from-leather via-leather/70 to-leather" />
      <div
        className="absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage:
            "repeating-linear-gradient(90deg, #F3E6C9 0 2px, transparent 2px 120px)",
        }}
      />
    </div>

    <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <SectionHeading kicker="The full season" title="Truth lives on the field">
        <p>
          Take your team through a full season, week by week, all the way to the championship. Every game is a case,
          and every case is settled on the field.
        </p>
      </SectionHeading>

      <div className="relative mt-16">
        <div
          className="pointer-events-none absolute left-0 right-0 top-[2.15rem] hidden h-[3px] lg:block"
          style={{ backgroundImage: "linear-gradient(90deg, #D8B266 60%, transparent 60%)", backgroundSize: "18px 3px" }}
          aria-hidden="true"
        />
        <ol className="relative grid gap-6 sm:grid-cols-2 lg:grid-cols-4 lg:gap-5">
        {stops.map((s, i) => {
          const last = i === stops.length - 1;
          return (
            <li key={s.title} className="relative">
              <div
                className={
                  last
                    ? "relative z-10 mx-auto flex h-[4.3rem] w-[4.3rem] items-center justify-center rounded-full bg-gradient-to-b from-[#f3d995] to-[#a9823b] text-ink shadow-[0_0_0_4px_#1E140D,0_0_0_6px_#D8B266,0_0_30px_rgba(216,178,102,0.6)] lg:mx-0"
                    : "relative z-10 mx-auto flex h-[4.3rem] w-[4.3rem] items-center justify-center rounded-full border-2 border-gold/80 bg-leather text-gold shadow-[0_0_0_4px_#1E140D] lg:mx-0"
                }
              >
                <s.icon className="h-7 w-7" strokeWidth={2} />
              </div>
              <div
                className={`mt-6 rounded-2xl p-6 text-center lg:text-left ${last ? "paper" : "leather-panel"}`}
              >
                <h3
                  className={`text-3xl font-black leading-none ${last ? "text-ink" : "text-cream"}`}
                >
                  {s.title}
                </h3>
                <p className={`mt-3 text-[0.95rem] leading-relaxed ${last ? "text-ink/75" : "text-cream/70"}`}>
                  {s.note}
                </p>
                {last && <span className="stamp mt-4 rotate-[-5deg] text-sm">Final</span>}
              </div>
            </li>
          );
        })}
        </ol>
      </div>

      <div className="mt-14 flex flex-col items-start gap-5 rounded-3xl border-2 border-gold/40 bg-leather/70 px-6 py-5 sm:rounded-full backdrop-blur-sm sm:flex-row sm:items-center sm:gap-6 sm:px-8">
        <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-tape text-ink">
          <Gauge className="h-6 w-6" strokeWidth={2.4} />
        </span>
        <div>
          <h3 className="text-2xl font-black leading-none text-cream">Several difficulty levels</h3>
          <p className="mt-1.5 text-[0.95rem] text-cream/70">
            Choose how hard the clues make you work, from an easy read to a case that fights back.
          </p>
        </div>
      </div>
    </div>
  </section>
);
