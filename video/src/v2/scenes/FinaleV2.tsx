// v2 scene "finale" (250 frames): "Now", the ŠEzVEM logo landing on the
// score's impact (frame 45), Kevin walking in and laughing, then an inverse
// circle close to pure black (215 -> 245, black until 250).
import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { CircleMaskOut } from "../../components/CircleMaskOut";
import { Kevin } from "../../components/Kevin";
import { SezvemLogo } from "../../components/Logo";
import { theme } from "../../theme";
import { Cue, LEVEL, Sfx } from "../Sfx";

// Beats, in frames local to this scene. LOGO_LAND and CLOSE are music-sync contracts.
const NOW_IN = 4;
const NOW_OUT = 24;
const LOGO_START = 27;
const LOGO_LAND = 45;
const SWEEP = [52, 82];
const KEVIN_IN = [64, 96];
const LAUGH = 100;
const CLOSE = 215;
const CLOSE_LEN = 30;

const LOGO_W = 820;
const LOGO_Y = -70; // logo sits a little above centre, leaving room for Kevin
const KEVIN_GROUND = 975;
const KEVIN_R = 80;

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

const steps: Cue[] = [];
for (let f = KEVIN_IN[0] + 4; f < KEVIN_IN[1]; f++) if (f % 9 === 0) steps.push({ at: f, name: "step", volume: LEVEL.character * 0.5 });

const CUES: Cue[] = [
  { at: NOW_IN, name: "hit", volume: LEVEL.impact * 0.75 },
  { at: LOGO_START - 2, name: "whoosh_soft", volume: LEVEL.transition },
  ...steps,
  { at: LAUGH, name: "laugh", volume: LEVEL.character },
  { at: LAUGH + 62, name: "laugh", volume: LEVEL.character * 0.7 },
  { at: CLOSE, name: "close", volume: LEVEL.impact * 0.7 },
];

export const FinaleV2: React.FC = () => {
  const frame = useCurrentFrame();

  // "Now": a quick, quiet rise, a deliberate hold, then it dissolves upward.
  const nowIn = interpolate(frame, [NOW_IN, NOW_IN + 8], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const nowOut = interpolate(frame, [NOW_OUT, NOW_OUT + 8], [1, 0], { ...clamp, easing: Easing.in(Easing.cubic) });
  const now = nowIn * nowOut;

  // Logo: opacity and gentle scale-in that is exactly complete at LOGO_LAND.
  const logoT = interpolate(frame, [LOGO_START, LOGO_LAND], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  // A very slow settle afterwards keeps the frame alive without distorting it.
  const drift = interpolate(frame, [LOGO_LAND, CLOSE], [1, 1.025], clamp);
  const logoScale = (0.9 + 0.1 * logoT) * drift;
  const glow = interpolate(frame, [LOGO_LAND - 4, LOGO_LAND + 10, LOGO_LAND + 60], [0, 0.55, 0.32], clamp);

  // Light sweep across the logo; fully off the logo before and after.
  const sweep = interpolate(frame, [SWEEP[0], SWEEP[1]], [-0.45, 1.45], { ...clamp, easing: Easing.inOut(Easing.cubic) });
  const sweepOn = frame > SWEEP[0] && frame < SWEEP[1];

  // Kevin walks in from the left to the centre, then laughs.
  const kx = interpolate(frame, KEVIN_IN, [-140, 960], { ...clamp, easing: Easing.out(Easing.quad) });
  const walking = frame >= KEVIN_IN[0] && frame < KEVIN_IN[1] - 2;

  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {/* Soft brand light behind the logo */}
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse 900px 520px at 50% ${50 + (LOGO_Y / 1080) * 100}%, rgba(30,158,106,${0.22 * glow}) 0%, transparent 70%)`,
        }}
      />

      {now > 0.001 ? (
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
          <div
            style={{
              fontFamily: theme.font,
              fontSize: 168,
              fontWeight: 600,
              letterSpacing: "-0.035em",
              color: "#fff",
              opacity: now,
              filter: `blur(${(1 - nowIn) * 12 + (1 - nowOut) * 8}px)`,
              transform: `translateY(${(1 - nowIn) * 26 - (1 - nowOut) * 18}px) scale(${0.97 + 0.03 * nowIn})`,
            }}
          >
            Now
          </div>
        </AbsoluteFill>
      ) : null}

      {frame >= LOGO_START ? (
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
          <div
            style={{
              position: "relative",
              width: LOGO_W,
              height: LOGO_W / 2,
              opacity: logoT,
              transform: `translateY(${LOGO_Y + (1 - logoT) * 24}px) scale(${logoScale})`,
              filter: `blur(${(1 - logoT) * 10}px) drop-shadow(0 30px 70px rgba(30,158,106,${glow * 0.6}))`,
            }}
          >
            <SezvemLogo width={LOGO_W} style={{ display: "block" }} />
            {sweepOn ? (
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: (112 / 1024) * LOGO_W,
                  overflow: "hidden",
                  mixBlendMode: "screen",
                }}
              >
                <div
                  style={{
                    position: "absolute",
                    top: "-20%",
                    bottom: "-20%",
                    width: "28%",
                    left: `${sweep * 100 - 14}%`,
                    background: "linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.28) 50%, transparent 100%)",
                    transform: "skewX(-18deg)",
                  }}
                />
              </div>
            ) : null}
          </div>
        </AbsoluteFill>
      ) : null}

      {frame >= KEVIN_IN[0] ? (
        <Kevin
          x={kx}
          y={KEVIN_GROUND}
          radius={KEVIN_R}
          walking={walking}
          facing={1}
          moods={[{ at: LAUGH, emotion: "laughing" }]}
        />
      ) : null}

      <CircleMaskOut from={CLOSE} duration={CLOSE_LEN} cx="50%" cy="50%" />
      {frame >= CLOSE + CLOSE_LEN ? <AbsoluteFill style={{ background: "#000" }} /> : null}
      <Sfx cues={CUES} />
    </AbsoluteFill>
  );
};
