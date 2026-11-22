// v2 scene "critical" (315 frames): the patient reports chest pain and Kevin
// escalates to urgent care. Starts in the exact state DETECT ends in.
import React from "react";
import { StageBackdrop } from "../FilmLook";
import { CompanionChat, KEVIN_QUESTION, KEVIN_REST_X, SPOTS } from "../../scenes/CompanionChat";

// Beats, in frames local to the scene.
export const CRITICAL_BEATS = {
  panToUser: 24, // camera leaves Kevin's question
  userTyping: 44, // typing indicator on the user side
  userMessage: 80, // user's answer lands
  panToKevin: 152, // after ~2.4 s of reading
  confused: 166,
  scared: 182, // ~0.53 s of confusion
  panToReply: 214,
  urgentReply: 230, // MUSIC SYNC: the score hits here
  fadeOut: 288, // last 45 frames are the held pause
} as const;

const B = CRITICAL_BEATS;

// Centred on the answer and high enough that Kevin is out of frame, not cut off at the bottom edge.
const USER_ANSWER = { ...SPOTS.userMsg, y: 430 };

export const CriticalV2: React.FC = () => (
  <CompanionChat
    sound
    backdrop={<StageBackdrop />}
    path={[{ at: 0, x: KEVIN_REST_X }]}
    moods={[
      { at: B.confused, emotion: "confused" },
      { at: B.scared, emotion: "scared" },
    ]}
    openAt={-30}
    messages={[
      { from: "kevin", text: KEVIN_QUESTION, at: -30 },
      {
        from: "user",
        text: "I'm not exercising. I feel pain. It started 10 minutes ago at 3, and it's now at 6. My SpO₂ is 93%.",
        typingFrom: B.userTyping,
        at: B.userMessage,
      },
      {
        from: "kevin",
        text: "These symptoms may be serious. Seek urgent medical attention immediately.",
        at: B.urgentReply,
        urgent: true,
      },
    ]}
    camera={[
      { at: 0, ...SPOTS.kevinMsg },
      { at: B.panToUser, ...SPOTS.kevinMsg },
      { at: B.userTyping, ...USER_ANSWER },
      { at: B.panToKevin, ...USER_ANSWER },
      { at: B.confused - 2, ...SPOTS.kevin },
      { at: B.panToReply, ...SPOTS.kevin },
      { at: B.urgentReply, ...SPOTS.reply },
    ]}
    fadeOutAt={B.fadeOut}
  />
);
