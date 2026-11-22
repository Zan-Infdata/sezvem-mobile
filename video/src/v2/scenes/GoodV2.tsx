// v2 scene "good" (345 frames): the positive alternative. Replays Kevin's
// question, the patient says they were running, Kevin is confused then laughs,
// replies, closes the chat and walks off screen.
import React from "react";
import { CompanionChat, KEVIN_QUESTION, KEVIN_REST_X, SPOTS } from "../../scenes/CompanionChat";
import { StageBackdrop } from "../FilmLook";

// Beats, in frames local to this scene.
const B = {
  question: 14, // Kevin's question pops in again: the replay
  userTyping: 56,
  userMsg: 78,
  toKevin: 138,
  confused: 146,
  laughing: 166,
  toReply: 204,
  reply: 212,
  close: 280,
  walkFrom: 288,
  walkTo: 328,
  fadeOut: 322,
};

const USER_Y = 440; // stage y that frames the user's reply
const REPLY_Y = 560; // frames Kevin's answer with Kevin fully in shot below it

export const GoodV2: React.FC = () => (
  <CompanionChat
    sound
    backdrop={<StageBackdrop />}
    path={[
      { at: 0, x: KEVIN_REST_X },
      { at: B.walkFrom, x: KEVIN_REST_X },
      { at: B.walkTo, x: 520 },
    ]}
    restFacing={1}
    moods={[
      { at: B.confused, emotion: "confused" },
      { at: B.laughing, emotion: "laughing" },
      { at: B.close - 6, emotion: "happy" },
    ]}
    openAt={-30}
    closeAt={B.close}
    messages={[
      { from: "kevin", text: KEVIN_QUESTION, at: B.question },
      { from: "user", text: "Yes, I went for a run. Anything wrong with that?", typingFrom: B.userTyping, at: B.userMsg },
      {
        from: "kevin",
        text: "Thanks for letting me know. I'll check on you when you finish your run. Have a good workout!",
        at: B.reply,
      },
    ]}
    camera={[
      { at: 0, ...SPOTS.kevinMsg },
      { at: B.userTyping - 8, ...SPOTS.kevinMsg },
      { at: B.userTyping + 8, x: SPOTS.userMsg.x, y: USER_Y, zoom: 1.6 },
      { at: B.toKevin, x: SPOTS.userMsg.x, y: USER_Y, zoom: 1.6 },
      { at: B.toKevin + 12, ...SPOTS.kevin },
      { at: B.toReply, ...SPOTS.kevin },
      { at: B.toReply + 12, x: SPOTS.reply.x, y: REPLY_Y, zoom: 1.55 },
      { at: B.close - 2, x: SPOTS.reply.x, y: REPLY_Y, zoom: 1.55 },
      { at: B.walkFrom + 4, x: "kevin", y: "kevin", zoom: 1.75 },
    ]}
    fadeOutAt={B.fadeOut}
  />
);
