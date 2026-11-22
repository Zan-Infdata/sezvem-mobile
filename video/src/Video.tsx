import React from "react";
import { AbsoluteFill, Series } from "remotion";
import { NarrativeText } from "./components/NarrativeText";
import { CompanionChat, KEVIN_QUESTION, KEVIN_REST_X, SPOTS } from "./scenes/CompanionChat";
import { Customize } from "./scenes/Customize";
import { Finale } from "./scenes/Finale";
import { Monitor } from "./scenes/Monitor";
import { Pairing } from "./scenes/Pairing";
import { TIMELINE as T } from "./timeline";
import { theme } from "./theme";

const green = (s: string) => <span style={{ color: theme.brand }}>{s}</span>;

const Detect = () => (
  <CompanionChat
    path={[{ at: 0, x: 470 }, { at: 12, x: 470 }, { at: 72, x: KEVIN_REST_X }]}
    moods={[{ at: 92, emotion: "typing" }, { at: 128, emotion: "resting" }]}
    openAt={80}
    messages={[{ from: "kevin", text: KEVIN_QUESTION, typingFrom: 94, at: 128 }]}
    camera={[
      { at: 0, ...SPOTS.wide },
      { at: 16, x: "kevin", y: "kevin", zoom: 1.45 },
      { at: 74, x: "kevin", y: "kevin", zoom: 1.45 },
      { at: 88, ...SPOTS.wide },
      { at: 100, ...SPOTS.kevin },
      { at: 118, ...SPOTS.kevin },
      { at: 132, ...SPOTS.kevinMsg },
    ]}
  />
);

const Critical = () => (
  <CompanionChat
    path={[{ at: 0, x: KEVIN_REST_X }]}
    moods={[{ at: 125, emotion: "confused" }, { at: 140, emotion: "scared" }]}
    openAt={-30}
    messages={[
      { from: "kevin", text: KEVIN_QUESTION, at: -30 },
      { from: "user", text: "I'm not exercising. I feel pain. It started 10 minutes ago at 3, and it's now at 6. My SpO₂ is 93%.", typingFrom: 22, at: 48 },
      { from: "kevin", text: "These symptoms may be serious. Seek urgent medical attention immediately.", at: 168, urgent: true },
    ]}
    camera={[
      { at: 0, ...SPOTS.kevinMsg },
      { at: 20, ...SPOTS.userMsg },
      { at: 112, ...SPOTS.userMsg },
      { at: 124, ...SPOTS.kevin },
      { at: 156, ...SPOTS.kevin },
      { at: 168, ...SPOTS.reply },
    ]}
    fadeOutAt={216}
  />
);

const Good = () => (
  <CompanionChat
    path={[{ at: 0, x: KEVIN_REST_X }, { at: 208, x: KEVIN_REST_X }, { at: 246, x: 520 }]}
    moods={[{ at: 100, emotion: "confused" }, { at: 116, emotion: "laughing" }, { at: 200, emotion: "happy" }]}
    openAt={-30}
    closeAt={198}
    messages={[
      { from: "kevin", text: KEVIN_QUESTION, at: 2 },
      { from: "user", text: "Yes, I went for a run. Anything wrong with that?", typingFrom: 36, at: 54 },
      { from: "kevin", text: "Thanks for letting me know. I'll check on you when you finish your run. Have a good workout!", at: 150 },
    ]}
    camera={[
      { at: 0, ...SPOTS.kevinMsg },
      { at: 32, ...SPOTS.kevinMsg },
      { at: 44, x: SPOTS.userMsg.x, y: 440, zoom: 1.6 },
      { at: 90, x: SPOTS.userMsg.x, y: 440, zoom: 1.6 },
      { at: 100, ...SPOTS.kevin },
      { at: 140, ...SPOTS.kevin },
      { at: 150, x: SPOTS.reply.x, y: 520, zoom: 1.6 },
      { at: 196, x: SPOTS.reply.x, y: 520, zoom: 1.6 },
      { at: 208, x: "kevin", y: "kevin", zoom: 1.6 },
    ]}
    fadeOutAt={238}
  />
);

export const SezvemPromo: React.FC = () => (
  <AbsoluteFill style={{ background: "#000" }}>
    <Series>
      <Series.Sequence durationInFrames={T.intro}>
        <NarrativeText
          lines={[
            { text: "We all know zVEM.", from: 0, to: 45 },
            { text: <>We are introducing {green("ŠEzVEM")}.</>, from: 60, to: 132 },
            { text: "A system for individual monitoring of patients after hospitalization.", from: 78, to: 132, size: 46, weight: 400, color: "#c9ced4" },
            { text: "In the comfort of your home!", from: 147, to: 195, size: 104, weight: 700, emphasis: true },
          ]}
        />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.pairing}>
        <Pairing />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.monitor}>
        <Monitor simStart={2} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.irregular}>
        <NarrativeText lines={[{ text: "Any irregularities?", from: 0, to: 45 }]} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.rise}>
        <Monitor simStart={4} rising />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.detect}>
        <Detect />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.critical}>
        <Critical />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.goodCard}>
        <NarrativeText lines={[{ text: "Or, in a good case...", from: 0, to: 45, color: "#d9f5e8" }]} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.good}>
        <Good />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.philosophy}>
        <NarrativeText
          gap={10}
          lines={[
            { text: <>Combining the {green("power of AI")}</>, from: 0, to: 105, size: 76 },
            { text: <>while keeping medical decisions</>, from: 16, to: 105, size: 76 },
            { text: <>{green("centralized")} and {green("deterministic")}.</>, from: 32, to: 105, size: 76 },
          ]}
        />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.customize}>
        <Customize />
      </Series.Sequence>
      <Series.Sequence durationInFrames={T.finale}>
        <Finale />
      </Series.Sequence>
    </Series>
  </AbsoluteFill>
);
