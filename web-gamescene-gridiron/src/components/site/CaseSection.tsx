import { FieldBoard } from "./FieldBoard";
import { MissingPlayerDemo } from "./MissingPlayerDemo";
import { Pin, Polaroid, SectionHeading } from "./Props";

const TeamFile = () => (
  <div className="folder flex h-full flex-col p-5 sm:p-8">
    <div className="folder-tab">Exhibit A</div>
    <span className="label-strip self-start">Your team</span>
    <h3 className="mt-4 text-3xl font-black leading-none text-ink sm:text-4xl">Create your own team</h3>
    <p className="mt-3 font-type text-sm leading-relaxed text-ink/75 sm:text-base">
      Every case starts with a roster. Build the team you'll take through the season. It's your name on the file.
    </p>

    <div className="relative mt-7 flex-1">
      <div className="note-paper relative rotate-[-1.5deg] px-5 pb-6 pt-7">
        <Pin className="left-5 top-2" />
        <dl className="space-y-4 font-type text-[0.95rem] text-ink">
          {["Team", "Roster", "Season"].map((k) => (
            <div key={k} className="flex items-end gap-3">
              <dt className="w-20 shrink-0 font-bold uppercase tracking-wider">{k}</dt>
              <dd className="h-5 flex-1 border-b-2 border-dotted border-ink/40" />
            </div>
          ))}
        </dl>
        <p className="mt-5 font-stamp text-sm text-ink/70">Filled in by you.</p>
      </div>
      <Polaroid
        src="/images/photo_helmet.jpg"
        alt="A football helmet resting on a locker room bench"
        caption="Locker room"
        rotate={6}
        className="ml-auto mt-[-1.5rem] w-[52%] max-w-[210px]"
      />
    </div>
  </div>
);

export const CaseSection = () => (
  <section id="case" className="relative scroll-mt-20 py-20 sm:py-28">
    <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
        <SectionHeading kicker="How a case works" title="Plays hide the truth">
          <p>
            A play happens. Someone is missing from it. You get the clues, the suspects and the field, and you work out
            who really made the play.
          </p>
        </SectionHeading>
        <span className="stamp stamp-on-dark rotate-[4deg] self-start text-lg lg:self-end">Evidence enclosed</span>
      </div>

      <div className="mt-14 grid gap-12 lg:grid-cols-12 lg:gap-8">
        <div className="lg:col-span-5">
          <TeamFile />
        </div>
        <div className="lg:col-span-7">
          <MissingPlayerDemo />
        </div>

        <div className="leather-panel relative rounded-3xl p-5 sm:p-8 lg:col-span-12">
          <div className="grid items-center gap-8 lg:grid-cols-[1fr_2.1fr]">
            <div>
              <span className="label-strip !bg-gold !text-ink">Exhibit C</span>
              <h3 className="headline-gold mt-4 text-4xl font-black leading-[0.95] sm:text-5xl">
                Place players on the field
              </h3>
              <p className="mt-4 text-base leading-relaxed text-cream/80">
                Once you've named the player, put them where the play says they stood. The empty spot only takes the
                right answer.
              </p>
              <p className="mt-5 font-stamp text-sm text-tape">Same game, different answers.</p>
            </div>
            <div className="rounded-2xl bg-black/30 p-2 shadow-[inset_0_0_0_1px_rgba(216,178,102,0.25)] sm:p-3">
              <FieldBoard />
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
);
