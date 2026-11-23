import type { CSSProperties, ReactNode } from "react";

import { cn } from "@/lib/utils";

export const Pin = ({ className, style }: { className?: string; style?: CSSProperties }) => (
  <span className={cn("pin", className)} style={style} aria-hidden="true" />
);

export const TapePiece = ({ className, style }: { className?: string; style?: CSSProperties }) => (
  <span className={cn("tape-piece", className)} style={style} aria-hidden="true" />
);

type PolaroidProps = {
  src: string;
  alt: string;
  caption: string;
  rotate?: number;
  className?: string;
  fastener?: "pin" | "tape";
};

export const Polaroid = ({ src, alt, caption, rotate = 0, className, fastener = "tape" }: PolaroidProps) => (
  <figure className={cn("polaroid", className)} style={{ transform: `rotate(${rotate}deg)` }}>
    {fastener === "tape" ? (
      <TapePiece className="-top-3 left-1/2 -translate-x-1/2 rotate-[-4deg]" />
    ) : (
      <Pin className="-top-2 left-1/2 -translate-x-1/2" />
    )}
    <div className="aspect-square overflow-hidden bg-ink">
      <img src={src} alt={alt} className="h-full w-full object-cover" loading="eager" />
    </div>
    <figcaption className="absolute inset-x-2 bottom-2.5 text-center font-stamp text-[0.82rem] leading-tight text-ink/80">
      {caption}
    </figcaption>
  </figure>
);

export const CautionTape = ({
  children,
  className,
  rotate = 0,
}: {
  children: ReactNode;
  className?: string;
  rotate?: number;
}) => (
  <div
    className={cn("caution relative flex h-11 items-center overflow-hidden", className)}
    style={{ transform: `rotate(${rotate}deg)` }}
  >
    <div className="flex w-max animate-marquee items-center gap-8 whitespace-nowrap">
      {[0, 1].map((half) => (
        <div key={half} className="flex items-center gap-8" aria-hidden={half === 1}>
          {Array.from({ length: 6 }).map((_, i) => (
            <span key={i} className="caution-label py-0.5 text-sm">
              {children}
            </span>
          ))}
        </div>
      ))}
    </div>
  </div>
);

export const SectionHeading = ({
  kicker,
  title,
  children,
  align = "left",
  className,
}: {
  kicker: string;
  title: ReactNode;
  children?: ReactNode;
  align?: "left" | "center";
  className?: string;
}) => (
  <div className={cn("max-w-3xl", align === "center" && "mx-auto text-center", className)}>
    <p className="kicker">{kicker}</p>
    <h2 className="headline-gold mt-3 text-[2.6rem] font-black leading-[0.92] sm:text-6xl lg:text-7xl">{title}</h2>
    {children && <div className="mt-5 text-base leading-relaxed text-cream/80 sm:text-lg">{children}</div>}
  </div>
);
