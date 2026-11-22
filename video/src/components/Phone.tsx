// Generic smartphone mockup, no device branding. Children fill the screen.
import React from "react";
import { theme } from "../theme";

export const PHONE = { w: 440, h: 900, bezel: 14 };
export const SCREEN = { w: PHONE.w - PHONE.bezel * 2, h: PHONE.h - PHONE.bezel * 2 };
/** Stage position of the screen's top-left when the phone is centred at (cx, cy). */
export const screenOrigin = (cx = 960, cy = 540) => ({ x: cx - SCREEN.w / 2, y: cy - SCREEN.h / 2 });

export const Phone: React.FC<{ cx?: number; cy?: number; dark?: boolean; children: React.ReactNode }> = ({
  cx = 960,
  cy = 540,
  dark = false,
  children,
}) => (
  <div
    style={{
      position: "absolute",
      left: cx - PHONE.w / 2,
      top: cy - PHONE.h / 2,
      width: PHONE.w,
      height: PHONE.h,
      borderRadius: 66,
      background: "#0b0c0e",
      boxShadow: "0 40px 120px rgba(0,0,0,0.45), inset 0 0 0 2px #2a2d33",
      padding: PHONE.bezel,
    }}
  >
    <div
      style={{
        position: "relative",
        width: SCREEN.w,
        height: SCREEN.h,
        borderRadius: 52,
        overflow: "hidden",
        background: dark ? "#0e1013" : "#f6f7f8",
        fontFamily: theme.font,
      }}
    >
      {children}
      <StatusBar dark={dark} />
    </div>
  </div>
);

const StatusBar: React.FC<{ dark: boolean }> = ({ dark }) => {
  const c = dark ? "#fff" : "#111";
  return (
    <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 44, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 30px", color: c, fontSize: 15, fontWeight: 600 }}>
      <span>9:41</span>
      <div style={{ position: "absolute", left: SCREEN.w / 2 - 50, top: 10, width: 100, height: 26, borderRadius: 13, background: "#000" }} />
      <span style={{ display: "flex", gap: 6, alignItems: "center" }}>
        <svg width="18" height="12" viewBox="0 0 18 12">{[0, 1, 2, 3].map((i) => <rect key={i} x={i * 4.5} y={9 - i * 3} width="3" height={3 + i * 3} rx="1" fill={c} />)}</svg>
        <svg width="26" height="12" viewBox="0 0 26 12"><rect x="0.5" y="0.5" width="22" height="11" rx="3" fill="none" stroke={c} opacity="0.5" /><rect x="2" y="2" width="17" height="8" rx="2" fill={c} /><rect x="23.5" y="4" width="2" height="4" rx="1" fill={c} opacity="0.5" /></svg>
      </span>
    </div>
  );
};

/** Generic home screen: wallpaper, unbranded app icons and a dock. */
export const HomeScreen: React.FC = () => {
  const icons = [
    ["#ff6b6b", "Calendar"], ["#4dabf7", "Weather"], ["#51cf66", "Messages"], ["#fcc419", "Notes"],
    ["#845ef7", "Podcasts"], ["#20c997", "Maps"], ["#ff922b", "Photos"], ["#339af0", "Mail"],
    ["#f06595", "Music"], ["#868e96", "Settings"], [theme.brand, "ŠEzVEM"], ["#495057", "Camera"],
  ];
  return (
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(160deg, #1b3b4f 0%, #2f5d62 45%, #b08968 100%)" }}>
      <div style={{ position: "absolute", top: 70, width: "100%", textAlign: "center", color: "rgba(255,255,255,0.92)" }}>
        <div style={{ fontSize: 72, fontWeight: 300, letterSpacing: -2 }}>9:41</div>
        <div style={{ fontSize: 17, opacity: 0.8 }}>Sunday, 22 November</div>
      </div>
      <div style={{ position: "absolute", top: 230, left: 28, right: 28, display: "grid", gridTemplateColumns: "repeat(4, 1fr)", rowGap: 26 }}>
        {icons.map(([c, n]) => (
          <div key={n} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
            <div style={{ width: 62, height: 62, borderRadius: 16, background: c, boxShadow: "0 4px 10px rgba(0,0,0,0.2)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              {n === "ŠEzVEM" ? <MiniLogo /> : <div style={{ width: 26, height: 26, borderRadius: 8, border: "3px solid rgba(255,255,255,0.85)" }} />}
            </div>
            <span style={{ fontSize: 12, color: "#fff", textShadow: "0 1px 2px rgba(0,0,0,0.4)" }}>{n}</span>
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", bottom: 18, left: 18, right: 18, height: 92, borderRadius: 32, background: "rgba(255,255,255,0.22)", display: "flex", justifyContent: "space-around", alignItems: "center" }}>
        {["#51cf66", "#4dabf7", "#ff922b", "#f06595"].map((c) => (
          <div key={c} style={{ width: 60, height: 60, borderRadius: 16, background: c }} />
        ))}
      </div>
    </div>
  );
};

const MiniLogo: React.FC = () => (
  <svg width="46" height="23" viewBox="0 0 1024 512">
    <g fill="none" stroke="#fff" strokeLinecap="round" strokeLinejoin="round" strokeWidth="40">
      <path d="M640 158 C 590 140, 520 162, 502 224 C 484 290, 536 350, 604 350 C 652 350, 686 326, 704 296" />
      <path d="M704 296 L 744 296 L 770 196 L 802 392 L 832 238 L 852 296 L 900 296" />
      <path d="M292 186 C 284 158, 236 142, 198 152 C 160 163, 150 196, 176 218 C 196 235, 236 240, 262 256 C 296 277, 300 314, 272 338 C 240 364, 182 360, 150 330" />
    </g>
  </svg>
);
