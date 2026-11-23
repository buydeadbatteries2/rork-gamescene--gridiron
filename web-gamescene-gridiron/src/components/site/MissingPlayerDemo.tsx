import { useState } from "react";
import { RotateCcw } from "lucide-react";

import { cn } from "@/lib/utils";

import { Pin } from "./Props";

type Option = { profile: string; verdict: string };

const ANSWER = "Elusive";

const clues = [
  "Three defenders had a clean shot. None of them made the tackle.",
  "He didn't outrun anyone. He made them miss.",
  "The broadcast camera lost him twice on the same play.",
];

const options: Option[] = [
  { profile: "Powerful", verdict: "No broken tackles on the tape. Nobody even touched him." },
  { profile: "Elusive", verdict: "Nobody could lay a hand on him. Case closed." },
  { profile: "Veteran", verdict: "Nothing in the clues points to experience." },
  { profile: "Fast", verdict: "Clue two rules it out. He never outran anyone." },
];

export const MissingPlayerDemo = () => {
  const [picked, setPicked] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const solved = picked === ANSWER;
  const current = options.find((o) => o.profile === picked);

  const choose = (profile: string) => {
    if (solved) return;
    setPicked(profile);
    setAttempt((a) => a + 1);
  };

  return (
    <div className="folder p-5 sm:p-8">
      <div className="folder-tab">Exhibit B</div>
      <Pin className="right-6 top-3" />

      <div className="flex flex-wrap items-center gap-3">
        <span className="label-strip">Missing player card</span>
        <span className="font-stamp text-xs uppercase tracking-[0.2em] text-ink/55">Sample case, try it</span>
      </div>

      <h3 className="mt-4 text-3xl font-black leading-none text-ink sm:text-4xl">Who made the play?</h3>
      <p className="mt-2 font-type text-sm text-ink/70 sm:text-base">
        Each card hides one player behind four possible profiles. The clues point to the right one.
      </p>

      <ol className="mt-5 space-y-2.5">
        {clues.map((c, i) => (
          <li
            key={c}
            className="flex gap-3 rounded-md border border-ink/15 bg-[#efe1c0]/70 px-3.5 py-2.5 font-type text-[0.95rem] leading-snug text-ink sm:text-base"
          >
            <span className="font-slab text-lg font-black leading-none text-stamp">{String.fromCharCode(65 + i)}</span>
            <span>{c}</span>
          </li>
        ))}
      </ol>

      <div className="mt-6">
        <p className="font-slab text-xs font-extrabold uppercase tracking-[0.24em] text-ink/60">Pick the profile</p>
        <div
          key={attempt}
          className={cn("mt-3 grid grid-cols-2 gap-2.5 sm:gap-3", picked && !solved && "animate-shake")}
          role="group"
          aria-label="Possible player profiles"
        >
          {options.map((o) => {
            const isPicked = picked === o.profile;
            const isAnswer = solved && o.profile === ANSWER;
            return (
              <button
                key={o.profile}
                type="button"
                onClick={() => choose(o.profile)}
                aria-pressed={isPicked}
                className={cn(
                  "rounded-full border-2 px-4 py-3 font-slab text-base font-extrabold uppercase tracking-[0.14em] transition-all duration-200 sm:text-lg",
                  "border-ink/80 bg-ink text-manila hover:-translate-y-0.5 hover:bg-[#3a2516] active:translate-y-0 active:scale-[0.98]",
                  isPicked && !solved && "border-stamp bg-stamp/90 text-cream",
                  isAnswer && "border-gold bg-gradient-to-b from-[#f3d995] to-[#c49a4e] text-ink shadow-[0_0_0_3px_rgba(36,23,13,0.9),0_0_22px_rgba(216,178,102,0.8)]",
                  solved && !isAnswer && "opacity-40",
                )}
              >
                {o.profile}
              </button>
            );
          })}
        </div>
      </div>

      <div className="mt-6 flex min-h-[4.5rem] flex-wrap items-center justify-between gap-4" aria-live="polite">
        {current ? (
          <>
            <div className="flex items-center gap-4">
              <span
                key={`${attempt}-stamp`}
                className="stamp animate-stamp text-lg sm:text-2xl"
                style={{ ["--r" as string]: solved ? "-6deg" : "4deg" }}
              >
                {solved ? "Identified" : "Not him"}
              </span>
              <p className="max-w-xs font-stamp text-sm leading-snug text-ink/80">{current.verdict}</p>
            </div>
            {solved && (
              <button
                type="button"
                onClick={() => setPicked(null)}
                className="inline-flex items-center gap-1.5 font-slab text-xs font-extrabold uppercase tracking-[0.2em] text-ink/65 hover:text-ink"
              >
                <RotateCcw className="h-3.5 w-3.5" /> Reset
              </button>
            )}
          </>
        ) : (
          <p className="font-stamp text-sm text-ink/55">Read all three clues, then make your call.</p>
        )}
      </div>
    </div>
  );
};
