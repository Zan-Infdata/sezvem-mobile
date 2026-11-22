// v2 scene "detect" (285 frames): Kevin walks onto the home screen, opens his
// chat, types, and asks about the sudden heart-rate rise.
// Handoff: ends with the chat open, Kevin resting at KEVIN_REST_X, the question
// shown and the camera at SPOTS.kevinMsg (held from frame 175 to the end).
import React from "react";
import { CompanionChat, KEVIN_QUESTION, KEVIN_REST_X, SPOTS } from "../../scenes/CompanionChat";
import { StageBackdrop } from "../FilmLook";

// Beats, in frames local to the scene.
const B = {
  walkFrom: 24, // Kevin starts walking in from the right edge
  walkTo: 100, // arrives at his resting spot
  notice: 102, // a startled hop: he noticed the reading
  open: 114, // chat panel opens
  wide: 130, // camera back on the whole phone
  typing: 132, // Kevin types
  onKevin: 142, // camera close on Kevin (about 0.5 s)
  message: 162, // the question appears
  onMessage: 176, // camera settles on the question, held to the end
};

export const DetectV2: React.FC = () => (
  <CompanionChat
    sound
    backdrop={<StageBackdrop />}
    path={[
      { at: 0, x: 470 },
      { at: B.walkFrom, x: 470 },
      { at: B.walkTo, x: KEVIN_REST_X },
    ]}
    moods={[
      { at: B.notice, emotion: "surprised" },
      { at: B.typing, emotion: "typing" },
      { at: B.message, emotion: "resting" },
    ]}
    openAt={B.open}
    messages={[{ from: "kevin", text: KEVIN_QUESTION, typingFrom: B.typing, at: B.message }]}
    camera={[
      { at: 0, ...SPOTS.wide },
      { at: B.walkFrom, ...SPOTS.wide },
      { at: B.walkFrom + 22, x: "kevin", y: "kevin", zoom: 1.4 },
      { at: B.walkTo + 4, x: "kevin", y: "kevin", zoom: 1.4 },
      { at: B.wide, ...SPOTS.wide },
      { at: B.onKevin, ...SPOTS.kevin },
      { at: B.message - 2, ...SPOTS.kevin },
      { at: B.onMessage, ...SPOTS.kevinMsg },
    ]}
  />
);
