const offense = [
  { x: 330, y: 150 },
  { x: 370, y: 150 },
  { x: 410, y: 150 },
  { x: 450, y: 150 },
  { x: 490, y: 150 },
  { x: 410, y: 190 },
  { x: 410, y: 240 },
  { x: 140, y: 152 },
  { x: 690, y: 152 },
  { x: 560, y: 168 },
];

const defense = [
  { x: 350, y: 112 },
  { x: 400, y: 112 },
  { x: 450, y: 112 },
  { x: 300, y: 82 },
  { x: 410, y: 70 },
  { x: 520, y: 82 },
  { x: 160, y: 78 },
  { x: 660, y: 78 },
  { x: 330, y: 22 },
  { x: 500, y: 22 },
];

const MISSING = { x: 250, y: 205 };

/** Chalk-on-turf play diagram with one empty slot for the missing player */
export const FieldBoard = () => (
  <svg viewBox="0 0 820 290" className="h-auto w-full" role="img" aria-label="A play diagram with one empty spot where the missing player belongs">
    <defs>
      <linearGradient id="turf" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stopColor="#173a22" />
        <stop offset="1" stopColor="#0f2617" />
      </linearGradient>
      <pattern id="mow" width="82" height="290" patternUnits="userSpaceOnUse">
        <rect width="41" height="290" fill="rgba(255,255,255,0.025)" />
      </pattern>
      <marker id="arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M0 0 L10 5 L0 10 z" fill="#F3E6C9" />
      </marker>
    </defs>
    <rect width="820" height="290" rx="14" fill="url(#turf)" />
    <rect width="820" height="290" rx="14" fill="url(#mow)" />
    {/* yard lines */}
    {Array.from({ length: 11 }).map((_, i) => (
      <line key={i} x1={i * 82} y1="0" x2={i * 82} y2="290" stroke="rgba(243,230,201,0.16)" strokeWidth="2" />
    ))}
    {/* line of scrimmage */}
    <line x1="0" y1="131" x2="820" y2="131" stroke="#D8B266" strokeWidth="2" strokeDasharray="8 7" opacity="0.7" />

    {/* routes */}
    <g fill="none" stroke="#F3E6C9" strokeWidth="2.4" strokeLinecap="round" opacity="0.85">
      <path d="M140 140 L140 60 L250 20" markerEnd="url(#arrow)" />
      <path d="M690 140 L690 50 L610 30" markerEnd="url(#arrow)" />
      <path d="M560 156 L600 100 L600 40" markerEnd="url(#arrow)" />
      <path
        d="M250 193 C 230 140, 300 120, 270 70 S 300 20, 360 14"
        stroke="#F2C230"
        strokeDasharray="6 8"
        markerEnd="url(#arrow)"
      />
    </g>

    {/* defense */}
    <g stroke="#F3E6C9" strokeWidth="3.2" strokeLinecap="round" opacity="0.9">
      {defense.map((p) => (
        <g key={`${p.x}-${p.y}`}>
          <line x1={p.x - 8} y1={p.y - 8} x2={p.x + 8} y2={p.y + 8} />
          <line x1={p.x + 8} y1={p.y - 8} x2={p.x - 8} y2={p.y + 8} />
        </g>
      ))}
    </g>

    {/* offense */}
    <g>
      {offense.map((p) => (
        <circle key={`${p.x}-${p.y}`} cx={p.x} cy={p.y} r="12" fill="#E3CFA6" stroke="#24170D" strokeWidth="3" />
      ))}
    </g>

    {/* missing player */}
    <g transform={`translate(${MISSING.x} ${MISSING.y})`}>
      <circle r="16" fill="none" stroke="#F2C230" strokeWidth="2.5" style={{ transformBox: "fill-box", transformOrigin: "center", animation: "pulse-ring 1.8s ease-out infinite" }} />
      <circle r="16" fill="#1E140D" stroke="#F2C230" strokeWidth="3" strokeDasharray="5 4" />
      <text y="7" textAnchor="middle" fontFamily="Roboto Slab, serif" fontWeight="900" fontSize="22" fill="#F2C230">
        ?
      </text>
    </g>
  </svg>
);
