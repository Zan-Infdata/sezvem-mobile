// v2 master: scenes from timeline.json joined by cross-dissolves, the scored
// music bed, transition whooshes and the film finishing layer.
import { Audio } from "@remotion/media";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import React from "react";
import { AbsoluteFill, staticFile } from "remotion";
import { FilmLook } from "./FilmLook";
import { SCENES } from "./scenes";
import { Cue, LEVEL, Sfx } from "./Sfx";
import timeline from "./timeline.json";

export const TR = timeline.transition;
export const V2_TOTAL = timeline.scenes.reduce((a, s) => a + s.duration, 0) - TR * (timeline.scenes.length - 1);

/** Global start frame of each scene (accounts for transition overlaps). */
export const sceneStart = (id: string) => {
  let acc = 0;
  for (const s of timeline.scenes) {
    if (s.id === id) return acc;
    acc += s.duration - TR;
  }
  throw new Error(id);
};

// Whooshes on cuts between two picture scenes (text cards bring their own).
const WHOOSH_INTO = ["monitor", "detect"];
const cutCues: Cue[] = WHOOSH_INTO.map((id) => ({ at: sceneStart(id) - 4, name: "whoosh", volume: LEVEL.transition }));

export const SezvemPromoV2: React.FC = () => (
  <AbsoluteFill style={{ background: "#000" }}>
    <TransitionSeries>
      {timeline.scenes.flatMap((s, i) => {
        const Scene = SCENES[s.id];
        const seq = (
          <TransitionSeries.Sequence key={s.id} name={s.id} durationInFrames={s.duration}>
            <Scene />
          </TransitionSeries.Sequence>
        );
        return i === 0
          ? [seq]
          : [<TransitionSeries.Transition key={`t-${s.id}`} presentation={fade()} timing={linearTiming({ durationInFrames: TR })} />, seq];
      })}
    </TransitionSeries>
    <Audio src={staticFile("audio/music.wav")} volume={0.6} />
    <Sfx cues={cutCues} />
    <FilmLook />
  </AbsoluteFill>
);

/** One scene alone with the finishing layer, for previews. */
export const SceneV2Preview: React.FC<{ id: string }> = ({ id }) => {
  const Scene = SCENES[id];
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Scene />
      <FilmLook />
    </AbsoluteFill>
  );
};
