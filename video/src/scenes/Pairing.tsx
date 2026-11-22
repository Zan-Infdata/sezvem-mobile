// Pairing a WHOOP in the IXland app: open, scan, select, connected.
import React from "react";
import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { ip } from "../anim";
import { Camera } from "../components/Camera";
import { Phone, screenOrigin } from "../components/Phone";
import { theme } from "../theme";

// Beat timing (frames within the scene).
const T = { tapScan: 30, found: 62, tapDevice: 84, connected: 104 };

// Cursor path in screen coordinates.
const CURSOR = [
  { at: 0, x: 330, y: 760 },
  { at: T.tapScan - 6, x: 206, y: 566 },
  { at: T.tapScan + 26, x: 206, y: 566 },
  { at: T.tapDevice - 6, x: 200, y: 486 },
  { at: T.tapDevice + 30, x: 200, y: 486 },
  { at: T.tapDevice + 50, x: 330, y: 800 },
];

export const Pairing: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const o = screenOrigin();
  const cx = ip(frame, CURSOR.map((c) => c.at), CURSOR.map((c) => c.x));
  const cy = ip(frame, CURSOR.map((c) => c.at), CURSOR.map((c) => c.y));
  const tap = (at: number) => (frame >= at && frame < at + 12 ? (frame - at) / 12 : -1);
  const tp = Math.max(tap(T.tapScan), tap(T.tapDevice));
  const scanning = frame >= T.tapScan + 4;
  const found = spring({ frame: frame - T.found, fps, config: { damping: 16 } });
  const connecting = frame >= T.tapDevice + 3 && frame < T.connected;
  const done = spring({ frame: frame - T.connected, fps, config: { damping: 12 } });

  const zoom = ip(frame, [0, 24, T.found, T.connected - 4, T.connected + 20], [1, 1.22, 1.3, 1.3, 1.12]);
  const camY = ip(frame, [0, 24, T.found, T.connected + 20], [540, 620, 590, 470]);

  return (
    <AbsoluteFill style={{ background: "radial-gradient(circle at 50% 40%, #20262d 0%, #0a0b0d 70%)" }}>
      <Camera view={{ x: 960, y: camY, zoom }}>
        <Phone>
          <div style={{ position: "absolute", inset: 0, background: "#f6f7f8", padding: "64px 22px 0" }}>
            <div style={{ fontSize: 14, color: theme.accent, fontWeight: 600, letterSpacing: 0.5 }}>‹ Devices</div>
            <div style={{ fontSize: 30, fontWeight: 650, color: theme.text, marginTop: 10, letterSpacing: -0.6 }}>Pair an existing device</div>
            <div style={{ fontSize: 15, color: theme.text2, marginTop: 6 }}>Connect your WHOOP so ŠEzVEM can follow your heart rate at home.</div>
            <div style={{ marginTop: 22, background: "#fff", borderRadius: 18, padding: 18, boxShadow: "0 1px 0 rgba(0,0,0,0.04)", border: `1px solid ${theme.hairline}` }}>
              <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                <div style={{ width: 52, height: 52, borderRadius: 14, background: "#111", color: "#fff", fontWeight: 800, fontSize: 13, display: "flex", alignItems: "center", justifyContent: "center", letterSpacing: 1 }}>WHOOP</div>
                <div>
                  <div style={{ fontSize: 18, fontWeight: 600, color: theme.text }}>WHOOP 4.0</div>
                  <div style={{ fontSize: 14, color: theme.muted }}>Bluetooth · heart rate</div>
                </div>
              </div>
              {/* Scan area */}
              <div style={{ position: "relative", height: 170, marginTop: 14, display: "flex", alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
                {scanning && frame < T.connected
                  ? [0, 1, 2].map((i) => {
                      const p = (((frame - T.tapScan) / 36 + i / 3) % 1 + 1) % 1;
                      return <div key={i} style={{ position: "absolute", width: 40 + p * 220, height: 40 + p * 220, borderRadius: "50%", border: `2px solid ${theme.accent}`, opacity: (1 - p) * 0.6 }} />;
                    })
                  : null}
                {frame >= T.connected ? (
                  <div style={{ width: 110, height: 110, borderRadius: "50%", background: theme.brand, transform: `scale(${done})`, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: `0 0 0 ${12 * done}px rgba(30,158,106,0.15)` }}>
                    <svg width="56" height="56" viewBox="0 0 24 24"><path d="M5 12.5 L10 17 L19 7" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" strokeDasharray="24" strokeDashoffset={24 * (1 - done)} /></svg>
                  </div>
                ) : (
                  <div style={{ fontSize: 15, color: theme.text2, zIndex: 1, background: "#fff", padding: "4px 10px", borderRadius: 8 }}>
                    {scanning ? (frame >= T.found ? "1 device found" : "Scanning for WHOOP…") : "Ready to scan"}
                  </div>
                )}
              </div>
              {/* Found device row */}
              {frame >= T.found ? (
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 14px", borderRadius: 14, background: frame >= T.tapDevice ? "#e6f4ef" : "#f6f7f8", border: `1.5px solid ${frame >= T.tapDevice ? theme.brand : "transparent"}`, opacity: found, transform: `translateY(${(1 - found) * 14}px)` }}>
                  <div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: theme.text }}>WHOOP 4.0 · 4A3F</div>
                    <div style={{ fontSize: 13, color: theme.muted }}>{connecting ? "Connecting…" : frame >= T.connected ? "Connected" : "Signal strong · tap to pair"}</div>
                  </div>
                  {connecting ? (
                    <div style={{ width: 22, height: 22, borderRadius: "50%", border: `3px solid ${theme.accent}`, borderTopColor: "transparent", transform: `rotate(${frame * 18}deg)` }} />
                  ) : (
                    <svg width="22" height="16" viewBox="0 0 22 16">{[0, 1, 2, 3].map((i) => <rect key={i} x={i * 6} y={12 - i * 4} width="4" height={4 + i * 4} rx="1" fill={theme.brand} />)}</svg>
                  )}
                </div>
              ) : null}
              {/* Scan button */}
              {frame < T.found ? (
                <div style={{ marginTop: 4, height: 52, borderRadius: 26, background: theme.accent, color: "#fff", fontSize: 17, fontWeight: 600, display: "flex", alignItems: "center", justifyContent: "center", transform: `scale(${tap(T.tapScan) >= 0 ? 0.96 : 1})` }}>
                  {scanning ? "Scanning…" : "Scan for WHOOP"}
                </div>
              ) : null}
            </div>
            {frame >= T.connected ? (
              <div style={{ marginTop: 22, textAlign: "center", opacity: done }}>
                <div style={{ fontSize: 22, fontWeight: 650, color: theme.brand }}>WHOOP connected</div>
                <div style={{ fontSize: 15, color: theme.text2, marginTop: 4 }}>Heart rate is now streaming to ŠEzVEM.</div>
              </div>
            ) : null}
          </div>
          {/* Touch cursor */}
          <div style={{ position: "absolute", left: cx - 22, top: cy - 22, width: 44, height: 44, borderRadius: "50%", background: "rgba(20,20,20,0.18)", border: "2px solid rgba(255,255,255,0.9)", boxShadow: "0 4px 14px rgba(0,0,0,0.25)", opacity: ip(frame, [T.connected + 30, T.connected + 44], [1, 0]) }} />
          {tp >= 0 ? <div style={{ position: "absolute", left: cx - 22 - tp * 30, top: cy - 22 - tp * 30, width: 44 + tp * 60, height: 44 + tp * 60, borderRadius: "50%", border: `3px solid ${theme.accent}`, opacity: 1 - tp }} /> : null}
        </Phone>
      </Camera>
    </AbsoluteFill>
  );
};
export const PAIRING_ORIGIN = screenOrigin;
