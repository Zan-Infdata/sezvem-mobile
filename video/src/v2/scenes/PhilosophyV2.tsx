// v2 product philosophy (135 frames): three lines building one sentence.
import React from "react";
import { KineticText } from "../KineticText";

export const PhilosophyV2: React.FC = () => (
  <KineticText
    duration={135}
    gap={8}
    lines={[
      { segments: ["Combining the ", { text: "power of AI", accent: true }], from: 10, to: 126, size: 80 },
      { segments: ["while keeping medical decisions"], from: 30, to: 126, size: 80, color: "#d7dbe0" },
      { segments: [{ text: "centralized", accent: true }, " and ", { text: "deterministic", accent: true }, "."], from: 50, to: 126, size: 80, stagger: 4 },
    ]}
  />
);
