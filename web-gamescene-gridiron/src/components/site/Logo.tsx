import { useId } from "react";

import { cn } from "@/lib/utils";

export const Shield = ({ className }: { className?: string }) => {
  const id = useId().replace(/:/g, "");
  return (
    <svg viewBox="0 0 100 116" className={className} aria-hidden="true">
      <defs>
        <linearGradient id={`g-${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#F8E3A8" />
          <stop offset="0.45" stopColor="#D8B266" />
          <stop offset="1" stopColor="#8E6A2C" />
        </linearGradient>
        <linearGradient id={`d-${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#3A2516" />
          <stop offset="1" stopColor="#170F09" />
        </linearGradient>
      </defs>
      <path
        d="M50 3 L93 16 V52 C93 82 72 102 50 113 C28 102 7 82 7 52 V16 Z"
        fill={`url(#g-${id})`}
        stroke="#5B4119"
        strokeWidth="1.5"
      />
      <path
        d="M50 11 L86 22 V52 C86 77 69 94 50 104 C31 94 14 77 14 52 V22 Z"
        fill={`url(#d-${id})`}
      />
      {/* football */}
      <g transform="translate(50 30)">
        <ellipse cx="0" cy="0" rx="17" ry="9" fill="none" stroke={`url(#g-${id})`} strokeWidth="2.4" />
        <line x1="-7" y1="0" x2="7" y2="0" stroke={`url(#g-${id})`} strokeWidth="1.8" />
        {[-4.5, -1.5, 1.5, 4.5].map((x) => (
          <line key={x} x1={x} y1="-2.6" x2={x} y2="2.6" stroke={`url(#g-${id})`} strokeWidth="1.4" />
        ))}
      </g>
      <text
        x="50"
        y="80"
        textAnchor="middle"
        fontFamily="Roboto Slab, Georgia, serif"
        fontWeight="900"
        fontSize="38"
        letterSpacing="-1"
        fill={`url(#g-${id})`}
      >
        GS
      </text>
    </svg>
  );
};

export const Logo = ({ className, compact = false }: { className?: string; compact?: boolean }) => (
  <a href="#top" className={cn("group flex items-center gap-3", className)} aria-label="GameScene: Gridiron home">
    <Shield className="h-11 w-auto drop-shadow-[0_4px_8px_rgba(0,0,0,0.6)] transition-transform duration-300 group-hover:-rotate-6 sm:h-12" />
    <span className="flex flex-col leading-none">
      <span className="headline-gold font-slab text-[1.45rem] font-black tracking-[0.04em] sm:text-[1.6rem]">
        GAMESCENE
      </span>
      {!compact && (
        <span className="mt-1 font-slab text-[0.66rem] font-bold tracking-[0.62em] text-cream/80 sm:text-[0.72rem]">
          GRIDIRON
        </span>
      )}
    </span>
  </a>
);
