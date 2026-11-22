// v2 scene "pairing" (225 frames): open the WHOOP pairing screen, scan, select
// the found WHOOP, connect, and hold on a clear success state.
import React from "react";
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { ip } from "../../anim";
import { Camera, cameraAt } from "../../components/Camera";
import { Phone, screenOrigin } from "../../components/Phone";
import { theme } from "../../theme";
import { StageBackdrop } from "../FilmLook";
import { LEVEL, Sfx } from "../Sfx";

// Beats, in frames local to the scene.
const B = {
  open: 14, // pairing screen slides in
  cursorIn: 42,
  tapScan: 70,
  found: 116,
  tapDevice: 146,
  connected: 172,
};

// Layout in screen coordinates (screen is 412 x 872).
const CARD = { top: 196, left: 18, width: 376 };
const ACTION_Y = 489; // centre of the scan button / found row
const SCAN_Y = 365; // centre of the scan area

// Touch cursor path (screen coordinates), eased between keys.
const CURSOR = [
  { at: B.cursorIn, x: 330, y: 780 },
  { at: B.tapScan - 6, x: 206, y: ACTION_Y + 4 },
  { at: B.tapScan + 22, x: 206, y: ACTION_Y + 4 },
  { at: B.found + 8, x: 300, y: 640 },
  { at: B.tapDevice - 6, x: 190, y: ACTION_Y + 2 },
  { at: B.tapDevice + 18, x: 190, y: ACTION_Y + 2 },
  { at: B.connected + 26, x: 320, y: 790 },
];

const o = screenOrigin();
const stage = (x: number, y: number) => ({ x: o.x + x, y: o.y + y });

const CAMERA = [
  { at: 0, x: 960, y: 540, zoom: 1 },
  { at: B.open + 10, x: 960, y: 540, zoom: 1.02 },
  { at: B.tapScan - 4, ...stage(206, 420), zoom: 1.3 },
  { at: B.found - 6, ...stage(206, 410), zoom: 1.32 },
  { at: B.tapDevice - 2, ...stage(206, 440), zoom: 1.38 },
  { at: B.connected + 4, ...stage(206, 420), zoom: 1.34 },
  { at: B.connected + 34, ...stage(206, 400), zoom: 1.16 },
  { at: 225, ...stage(206, 396), zoom: 1.13 },
];

export const PairingV2: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const cx = ip(frame, CURSOR.map((c) => c.at), CURSOR.map((c) => c.x));
  const cy = ip(frame, CURSOR.map((c) => c.at), CURSOR.map((c) => c.y));
  const cursorOpacity = Math.min(ip(frame, [B.cursorIn, B.cursorIn + 10], [0, 1]), ip(frame, [B.connected + 16, B.connected + 30], [1, 0]));
  const press = (at: number) => (frame >= at - 3 && frame < at + 6 ? Math.sin(((frame - at + 3) / 9) * Math.PI) : 0);
  const pressing = Math.max(press(B.tapScan), press(B.tapDevice));
  const ripple = (at: number) => (frame >= at && frame < at + 18 ? (frame - at) / 18 : -1);
  const rp = Math.max(ripple(B.tapScan), ripple(B.tapDevice));

  const open = spring({ frame: frame - B.open, fps, config: { damping: 200 }, durationInFrames: 22 });
  const scanning = frame >= B.tapScan + 3 && frame < B.connected;
  const found = spring({ frame: frame - B.found, fps, config: { damping: 18, stiffness: 140 } });
  const selected = frame >= B.tapDevice;
  const connecting = frame >= B.tapDevice + 3 && frame < B.connected;
  const done = spring({ frame: frame - B.connected, fps, config: { damping: 13, stiffness: 120 } });
  const doneText = spring({ frame: frame - B.connected - 8, fps, config: { damping: 200 }, durationInFrames: 20 });
  const isDone = frame >= B.connected;

  // Status text in the scan area.
  const status = !scanning && !isDone ? "Ready to scan" : frame < B.found ? "Scanning for WHOOP…" : "1 device found";

  return (
    <AbsoluteFill>
      <StageBackdrop />
      <Camera view={cameraAt(frame, CAMERA)}>
        <Phone>
          {/* App root behind the pushed screen */}
          <div style={{ position: "absolute", inset: 0, background: "#eef0f2" }}>
            <div style={{ position: "absolute", top: 64, left: 24, fontSize: 30, fontWeight: 650, color: theme.text, letterSpacing: -0.6 }}>Devices</div>
            <div style={{ position: "absolute", top: 120, left: 18, right: 18, display: "flex", flexDirection: "column", gap: 10 }}>
              {[
                ["WHOOP 4.0", "Not paired"],
                ["Galaxy Watch", "Not paired"],
              ].map(([n, s]) => (
                <div key={n} style={{ background: "#fff", borderRadius: 16, padding: "14px 16px", display: "flex", justifyContent: "space-between", border: `1px solid ${theme.hairline}` }}>
                  <span style={{ fontSize: 16, fontWeight: 600, color: theme.text }}>{n}</span>
                  <span style={{ fontSize: 13, color: theme.muted }}>{s} ›</span>
                </div>
              ))}
            </div>
          </div>
          {/* Pairing screen */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "#f6f7f8",
              transform: `translateX(${(1 - open) * 100}%)`,
              boxShadow: "-20px 0 40px rgba(0,0,0,0.08)",
              fontFamily: theme.font,
            }}
          >
            <div style={{ position: "absolute", top: 56, left: 22, fontSize: 15, color: theme.accent, fontWeight: 600 }}>‹ Devices</div>
            <div style={{ position: "absolute", top: 84, left: 22, right: 22 }}>
              <div style={{ fontSize: 30, fontWeight: 700, color: theme.text, letterSpacing: -0.8 }}>Pair an existing device</div>
              <div style={{ fontSize: 15, color: theme.text2, marginTop: 8, lineHeight: 1.4 }}>
                Connect your WHOOP so ŠEzVEM can follow your heart rate at home.
              </div>
            </div>

            {/* Device card */}
            <div
              style={{
                position: "absolute",
                top: CARD.top,
                left: CARD.left,
                width: CARD.width,
                height: 350,
                background: "#fff",
                borderRadius: 22,
                border: `1px solid ${theme.hairline}`,
                boxShadow: "0 12px 32px rgba(16,24,40,0.07), 0 2px 6px rgba(16,24,40,0.04)",
              }}
            >
              <div style={{ position: "absolute", top: 18, left: 18, right: 18, display: "flex", alignItems: "center", gap: 14 }}>
                <WhoopBadge />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 18, fontWeight: 650, color: theme.text }}>WHOOP 4.0</div>
                  <div style={{ fontSize: 13.5, color: theme.muted, marginTop: 2 }}>Bluetooth · heart rate</div>
                </div>
                <div
                  style={{
                    fontSize: 12,
                    fontWeight: 600,
                    padding: "5px 10px",
                    borderRadius: 999,
                    color: isDone ? theme.brand : theme.muted,
                    background: isDone ? "rgba(30,158,106,0.1)" : "#f1f3f5",
                  }}
                >
                  {isDone ? "Paired" : "Not paired"}
                </div>
              </div>

              {/* Scan area */}
              <div style={{ position: "absolute", top: SCAN_Y - CARD.top - 85, left: 0, right: 0, height: 170, display: "flex", alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
                {scanning
                  ? [0, 1, 2].map((i) => {
                      const p = ((((frame - B.tapScan) / 42 + i / 3) % 1) + 1) % 1;
                      const fadeOut = ip(frame, [B.connected - 10, B.connected], [1, 0]);
                      return (
                        <div
                          key={i}
                          style={{
                            position: "absolute",
                            width: 60 + p * 230,
                            height: 60 + p * 230,
                            borderRadius: "50%",
                            border: `2px solid ${theme.accent}`,
                            opacity: (1 - p) * 0.45 * fadeOut,
                          }}
                        />
                      );
                    })
                  : null}
                {isDone ? (
                  <div
                    style={{
                      width: 104,
                      height: 104,
                      borderRadius: "50%",
                      background: `linear-gradient(160deg, #27b57c, ${theme.brand})`,
                      transform: `scale(${done})`,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      boxShadow: `0 0 0 ${14 * done}px rgba(30,158,106,0.12), 0 12px 28px rgba(30,158,106,0.35)`,
                    }}
                  >
                    <svg width="54" height="54" viewBox="0 0 24 24">
                      <path
                        d="M5 12.5 L10 17 L19 7"
                        fill="none"
                        stroke="#fff"
                        strokeWidth="2.6"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeDasharray="24"
                        strokeDashoffset={24 * (1 - ip(frame, [B.connected + 4, B.connected + 18], [0, 1]))}
                      />
                    </svg>
                  </div>
                ) : (
                  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, zIndex: 1 }}>
                    <BandGlyph active={scanning} frame={frame} />
                    <div style={{ fontSize: 14.5, color: theme.text2, background: "#fff", padding: "2px 10px", borderRadius: 8 }}>{status}</div>
                  </div>
                )}
              </div>

              {/* Action slot: scan button, then the found device row */}
              <div style={{ position: "absolute", top: ACTION_Y - CARD.top - 28, left: 16, right: 16, height: 56 }}>
                {frame < B.found + 6 ? (
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      borderRadius: 28,
                      background: scanning ? "#e7f1ef" : theme.accent,
                      color: scanning ? theme.accent : "#fff",
                      fontSize: 17,
                      fontWeight: 600,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: 10,
                      boxShadow: scanning ? "none" : "0 8px 18px rgba(15,118,110,0.28)",
                      transform: `scale(${1 - press(B.tapScan) * 0.04})`,
                      opacity: 1 - found,
                    }}
                  >
                    {scanning ? <Spinner frame={frame} color={theme.accent} /> : null}
                    {scanning ? "Scanning…" : "Scan for WHOOP"}
                  </div>
                ) : null}
                {frame >= B.found ? (
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: "0 16px",
                      borderRadius: 16,
                      background: isDone ? "#e8f6ef" : selected ? "#eef6f4" : "#f6f7f8",
                      border: `1.5px solid ${selected ? theme.brand : "rgba(22,25,29,0.06)"}`,
                      opacity: found,
                      transform: `translateY(${(1 - found) * 14}px) scale(${1 - press(B.tapDevice) * 0.03})`,
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 16, fontWeight: 650, color: theme.text }}>WHOOP 4.0 · 4A3F</div>
                      <div style={{ fontSize: 13, color: isDone ? theme.brand : theme.muted, fontWeight: isDone ? 600 : 400 }}>
                        {connecting ? "Connecting…" : isDone ? "Connected" : "Signal strong · tap to pair"}
                      </div>
                    </div>
                    {connecting ? (
                      <Spinner frame={frame} color={theme.accent} />
                    ) : isDone ? (
                      <svg width="22" height="22" viewBox="0 0 24 24">
                        <circle cx="12" cy="12" r="11" fill={theme.brand} />
                        <path d="M7 12.5 L10.5 16 L17 8.5" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    ) : (
                      <svg width="22" height="16" viewBox="0 0 22 16">
                        {[0, 1, 2, 3].map((i) => (
                          <rect key={i} x={i * 6} y={12 - i * 4} width="4" height={4 + i * 4} rx="1" fill={theme.brand} />
                        ))}
                      </svg>
                    )}
                  </div>
                ) : null}
              </div>
            </div>

            {/* Success message */}
            {isDone ? (
              <div style={{ position: "absolute", top: 570, left: 22, right: 22, textAlign: "center", opacity: doneText, transform: `translateY(${(1 - doneText) * 12}px)` }}>
                <div style={{ fontSize: 23, fontWeight: 700, color: theme.brand, letterSpacing: -0.4 }}>WHOOP connected</div>
                <div style={{ fontSize: 15, color: theme.text2, marginTop: 6 }}>Heart rate is now streaming to ŠEzVEM.</div>
                <LivePill frame={frame} />
              </div>
            ) : null}

            <div style={{ position: "absolute", bottom: 34, left: 0, right: 0, textAlign: "center", fontSize: 12.5, color: theme.muted }}>
              Keep the band close to your phone while pairing.
            </div>
          </div>

          {/* Touch cursor */}
          <div
            style={{
              position: "absolute",
              left: cx - 22,
              top: cy - 22,
              width: 44,
              height: 44,
              borderRadius: "50%",
              background: "rgba(22,25,29,0.16)",
              border: "2px solid rgba(255,255,255,0.95)",
              boxShadow: "0 6px 16px rgba(0,0,0,0.22)",
              opacity: cursorOpacity,
              transform: `scale(${1 - pressing * 0.18})`,
            }}
          />
          {rp >= 0 ? (
            <div
              style={{
                position: "absolute",
                left: cx - 22 - rp * 34,
                top: cy - 22 - rp * 34,
                width: 44 + rp * 68,
                height: 44 + rp * 68,
                borderRadius: "50%",
                border: `2.5px solid ${theme.accent}`,
                opacity: (1 - rp) * 0.8,
              }}
            />
          ) : null}
        </Phone>
      </Camera>
      <Sfx
        cues={[
          { at: B.tapScan, name: "tap", volume: LEVEL.ui },
          { at: B.tapScan + 4, name: "sonar", volume: LEVEL.ui * 0.7 },
          { at: B.tapScan + 46, name: "sonar", volume: LEVEL.ui * 0.55 },
          { at: B.found, name: "found", volume: LEVEL.ui },
          { at: B.tapDevice, name: "tap", volume: LEVEL.ui },
          { at: B.connected, name: "success", volume: LEVEL.ui * 1.1 },
        ]}
      />
    </AbsoluteFill>
  );
};

const WhoopBadge: React.FC = () => (
  <div
    style={{
      width: 52,
      height: 52,
      borderRadius: 14,
      background: "linear-gradient(160deg, #2a2d33, #0d0e10)",
      color: "#fff",
      fontWeight: 800,
      fontSize: 11.5,
      letterSpacing: 1.2,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      boxShadow: "inset 0 1px 0 rgba(255,255,255,0.12)",
    }}
  >
    WHOOP
  </div>
);

/** A simple strap glyph that breathes while scanning. */
const BandGlyph: React.FC<{ active: boolean; frame: number }> = ({ active, frame }) => {
  const k = active ? 1 + Math.sin(frame / 6) * 0.04 : 1;
  return (
    <svg width="64" height="40" viewBox="0 0 64 40" style={{ transform: `scale(${k})` }}>
      <rect x="2" y="13" width="60" height="14" rx="7" fill="#d9dde2" />
      <rect x="18" y="6" width="28" height="28" rx="8" fill="#16191d" />
      <circle cx="32" cy="20" r="3" fill={active ? theme.brand : "#4a525c"} />
    </svg>
  );
};

const Spinner: React.FC<{ frame: number; color: string }> = ({ frame, color }) => (
  <div style={{ width: 20, height: 20, borderRadius: "50%", border: `2.5px solid ${color}`, borderTopColor: "transparent", transform: `rotate(${frame * 16}deg)` }} />
);

/** A small live heart-rate pill that hands off to the monitor scene. */
const LivePill: React.FC<{ frame: number }> = ({ frame }) => {
  const appear = interpolate(frame, [B.connected + 22, B.connected + 36], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const beat = Math.exp(-(((frame - B.connected) % 23) / 23) * 6);
  const bpm = 79 + Math.round(Math.sin(frame / 20));
  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 8,
        marginTop: 18,
        padding: "8px 14px",
        borderRadius: 999,
        background: "#16191d",
        color: "#e8eaed",
        fontFamily: theme.mono,
        fontSize: 14,
        opacity: appear,
        transform: `translateY(${(1 - appear) * 8}px)`,
      }}
    >
      <span style={{ width: 8, height: 8, borderRadius: 4, background: theme.normal, boxShadow: `0 0 ${4 + beat * 8}px ${theme.normal}` }} />
      {bpm} bpm · live
    </div>
  );
};
