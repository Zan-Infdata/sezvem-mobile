// Phone home screen with Kevin walking on top of it and his chat panel.
// One scene component drives the detection, critical and good-case beats.
import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { ip } from "../anim";
import { Camera, cameraAt } from "../components/Camera";
import { ChatMessage, ChatPanel } from "../components/Chat";
import { KEVIN, Kevin, MoodKey } from "../components/Kevin";
import { HomeScreen, Phone, screenOrigin } from "../components/Phone";
import { Cue, LEVEL, Sfx } from "../v2/Sfx";

export const KEVIN_GROUND = 760; // screen y of Kevin's feet
export const KEVIN_REST_X = 78;
const KEVIN_R = 46;

export type FollowKey = { at: number; x: number | "kevin"; y: number | "kevin"; zoom: number };
export type PathKey = { at: number; x: number };

export const CompanionChat: React.FC<{
  path: PathKey[];
  restFacing?: 1 | -1;
  moods?: MoodKey[];
  messages: ChatMessage[];
  openAt?: number;
  closeAt?: number;
  camera: FollowKey[];
  fadeOutAt?: number;
  /** v2: play Kevin's footsteps, mood sounds and chat sounds automatically. */
  sound?: boolean;
  /** v2: replaces the default backdrop behind the phone. */
  backdrop?: React.ReactNode;
}> = ({ path, restFacing = 1, moods = [], messages, openAt = Infinity, closeAt, camera, fadeOutAt, sound = false, backdrop }) => {
  const frame = useCurrentFrame();
  const o = screenOrigin();
  const xAt = (f: number) => (path.length === 1 ? path[0].x : ip(f, path.map((p) => p.at), path.map((p) => p.x), (t) => t));
  const kx = xAt(frame);
  const dx = xAt(frame + 1) - kx;
  const walking = Math.abs(dx) > 0.05;
  const facing: 1 | -1 = walking ? (dx < 0 ? -1 : 1) : restFacing;
  const stage = { x: o.x + kx, y: o.y + KEVIN_GROUND - KEVIN_R * 0.9 };
  const keys = camera.map((k) => ({
    at: k.at,
    x: k.x === "kevin" ? stage.x : k.x,
    y: k.y === "kevin" ? stage.y : k.y,
    zoom: k.zoom,
  }));
  const fade = fadeOutAt === undefined ? 1 : ip(frame, [fadeOutAt, fadeOutAt + 12], [1, 0]);
  return (
    <AbsoluteFill style={{ background: "radial-gradient(circle at 50% 40%, #20262d 0%, #0a0b0d 70%)", opacity: fade }}>
      {backdrop}
      {sound ? <Sfx cues={kevinCues(path, moods, messages, openAt, closeAt)} /> : null}
      <Camera view={cameraAt(frame, keys)}>
        <Phone>
          <HomeScreen />
          <ChatPanel messages={messages} openAt={openAt} closeAt={closeAt} style={{ left: 14, right: 14, top: 58, height: 600 }} />
          <Kevin x={kx} y={KEVIN_GROUND} radius={KEVIN_R} look={KEVIN} moods={moods} walking={walking} facing={facing} />
        </Phone>
      </Camera>
    </AbsoluteFill>
  );
};

// Script shared by both patient scenarios.
export const KEVIN_QUESTION =
  "Your heart rate has increased suddenly. Are you exercising? If not, please tell me if you feel any pain in your chest. On a scale from 1 to 10, where 1 is no pain and 10 is unbearable pain, how severe is it? Also, please measure your SpO₂.";

// Stage points the camera visits (phone centred at 960,540; screen origin 754,104).
export const SPOTS = {
  wide: { x: 960, y: 540, zoom: 1 },
  kevinMsg: { x: 925, y: 300, zoom: 1.7 },
  userMsg: { x: 1010, y: 490, zoom: 1.6 },
  reply: { x: 925, y: 590, zoom: 1.6 },
  kevin: { x: 860, y: 800, zoom: 1.9 },
};

const MOOD_SOUND = { surprised: "found", confused: "confused", scared: "scared", laughing: "laugh", happy: "sparkle", typing: "typing" } as const;

/** Sound cues derived from the scene script, so every chat scene sounds the same. */
export function kevinCues(path: PathKey[], moods: MoodKey[], messages: ChatMessage[], openAt: number, closeAt?: number): Cue[] {
  const cues: Cue[] = [];
  // Footsteps: the walk cycle is 18 frames with two ground contacts.
  for (let i = 1; i < path.length; i++) {
    if (path[i].x === path[i - 1].x) continue;
    for (let f = path[i - 1].at + 4; f < path[i].at; f++) if (f % 9 === 0) cues.push({ at: f, name: "step", volume: LEVEL.character * 0.55 });
  }
  for (const m of moods) {
    const name = MOOD_SOUND[m.emotion as keyof typeof MOOD_SOUND];
    if (name) cues.push({ at: m.at, name, volume: LEVEL.character });
  }
  if (Number.isFinite(openAt)) cues.push({ at: openAt, name: "pop_open", volume: LEVEL.ui });
  if (closeAt !== undefined) cues.push({ at: closeAt, name: "pop_close", volume: LEVEL.ui });
  for (const m of messages) {
    if (m.typingFrom !== undefined && m.from === "user") cues.push({ at: m.typingFrom, name: "typing", volume: LEVEL.ui * 0.8 });
    cues.push({ at: m.at, name: m.from === "kevin" ? "msg_in" : "msg_out", volume: m.urgent ? LEVEL.alert : LEVEL.ui });
  }
  return cues;
}
