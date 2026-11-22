// v2 "Or, in a good case..." (60 frames): lighter, optimistic card.
import React from "react";
import { KineticText } from "../KineticText";

export const GoodCardV2: React.FC = () => (
  <KineticText
    duration={60}
    lines={[{ segments: ["Or, in a ", { text: "good case", accent: true }, "..."], from: 8, to: 54, size: 96, weight: 500, color: "#f2fbf6", stagger: 4 }]}
  />
);
