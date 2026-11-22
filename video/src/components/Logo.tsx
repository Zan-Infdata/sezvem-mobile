// The ŠEzVEM logo, exactly as supplied.
import React from "react";

export const SezvemLogo: React.FC<{ width: number; style?: React.CSSProperties }> = ({ width, style }) => (
  <svg className="logo home-logo" viewBox="0 0 1024 512" width={width} height={width / 2} aria-hidden="true" style={style}>
    <rect x="0" y="0" width="1024" height="512" rx="112" fill="#1e9e6a" />
    <g fill="none" stroke="#ffffff" strokeLinecap="round" strokeLinejoin="round">
      <g transform="translate(-56 6) rotate(-6 260 256)">
        <path strokeWidth="24" d="M292 186 C 284 158, 236 142, 198 152 C 160 163, 150 196, 176 218 C 196 235, 236 240, 262 256 C 296 277, 300 314, 272 338 C 240 364, 182 360, 150 330" />
        <path strokeWidth="18" d="M178 96 C 192 108, 206 120, 224 128 C 240 112, 258 98, 274 90" />
        <path strokeWidth="24" d="M352 162 C 348 210, 350 286, 356 342" />
        <path strokeWidth="22" d="M354 164 C 384 160, 410 158, 436 166" />
        <path strokeWidth="20" d="M356 250 C 378 246, 398 248, 414 254" />
        <path strokeWidth="22" d="M358 340 C 388 344, 418 342, 446 334" />
      </g>
      <path strokeWidth="24" d="M640 158 C 590 140, 520 162, 502 224 C 484 290, 536 350, 604 350 C 652 350, 686 326, 704 296" />
      <path strokeWidth="30" d="M546 214 L 626 214 L 548 294 L 632 294" />
      <path strokeWidth="22" d="M704 296 L 744 296 L 770 196 L 802 392 L 832 238 L 852 296 L 900 296" />
    </g>
  </svg>
);
