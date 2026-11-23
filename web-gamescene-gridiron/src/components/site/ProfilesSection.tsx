import { CautionTape, SectionHeading } from "./Props";

const profiles = [
  { name: "Rookie", note: "New to the league. Raw, hungry, unproven." },
  { name: "Veteran", note: "Has seen every look a defense can throw." },
  { name: "Fast", note: "Gone before the safety turns his hips." },
  { name: "Powerful", note: "Breaks tackles. Moves piles." },
  { name: "Overrated", note: "The name is bigger than the tape." },
  { name: "Underrated", note: "The tape is bigger than the name." },
  { name: "Elusive", note: "Hard to catch. Harder to pin down." },
  { name: "Reliable", note: "Shows up every snap, every week." },
  { name: "Technical", note: "Wins with footwork and precision." },
];

const tilts = [-1.6, 1.2, -0.6, 1.8, -1.2, 0.8, -1.8, 1.4, -0.8];

export const ProfilesSection = () => (
  <section id="profiles" className="relative scroll-mt-20 pb-24 pt-6 sm:pb-32">
    <div className="mb-14 overflow-hidden py-6 sm:mb-16">
      <CautionTape className="-ml-[5%] w-[110%]" rotate={-1.2}>
        Plays hide the truth
      </CautionTape>
    </div>

    <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <SectionHeading kicker="The suspects" title="Know your profiles" align="center">
        <p>
          Nine kinds of player. Every missing-player card puts four of them on the table, and only one fits the clues.
        </p>
      </SectionHeading>

      <ul className="mt-16 grid grid-cols-1 gap-x-6 gap-y-12 min-[480px]:grid-cols-2 lg:grid-cols-3">
        {profiles.map((p, i) => (
          <li
            key={p.name}
            className="folder group px-5 pb-5 pt-5 transition-transform duration-300 hover:!rotate-0 hover:-translate-y-1"
            style={{ transform: `rotate(${tilts[i]}deg)` }}
          >
            <div className="folder-tab text-[0.7rem]">Profile</div>
            <div className="flex items-start justify-between gap-3">
              <h3 className="text-[2rem] font-black leading-none text-ink sm:text-[2.3rem]">{p.name}</h3>
              <span className="stamp mt-1 shrink-0 rotate-[8deg] text-[0.6rem] opacity-70 transition-opacity group-hover:opacity-100">
                On file
              </span>
            </div>
            <div className="my-3 h-px bg-ink/20" />
            <p className="font-stamp text-[0.95rem] leading-snug text-ink/80">{p.note}</p>
          </li>
        ))}
      </ul>
    </div>
  </section>
);
