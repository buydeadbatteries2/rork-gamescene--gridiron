import { Smartphone } from "lucide-react";

import { Logo } from "./Logo";

const links = [
  { href: "#case", label: "The case" },
  { href: "#profiles", label: "Profiles" },
  { href: "#season", label: "Season" },
  { href: "#clubhouse", label: "Clubhouse" },
];

export const Header = () => (
  <header className="sticky top-0 z-50 border-b border-gold/20 bg-leather/80 backdrop-blur-md">
    <div className="mx-auto flex h-[4.5rem] max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
      <Logo />
      <nav className="hidden items-center gap-8 md:flex" aria-label="Main">
        {links.map((l) => (
          <a
            key={l.href}
            href={l.href}
            className="font-slab text-sm font-bold uppercase tracking-[0.2em] text-cream/75 transition-colors hover:text-gold"
          >
            {l.label}
          </a>
        ))}
      </nav>
      <a
        href="#coming-soon"
        className="inline-flex items-center gap-2 rounded-full border-2 border-gold/70 px-3.5 py-2 font-slab text-[0.7rem] font-extrabold uppercase tracking-[0.14em] text-gold transition-colors hover:bg-gold hover:text-ink sm:px-4 sm:text-xs"
      >
        <Smartphone className="h-4 w-4" />
        <span className="hidden min-[400px]:inline">Coming soon to iPhone</span>
        <span className="min-[400px]:hidden">Coming soon</span>
      </a>
    </div>
  </header>
);
