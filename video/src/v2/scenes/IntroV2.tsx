// v2 intro (220 frames): four narrative beats on pure black.
import React from "react";
import { KineticText } from "../KineticText";

export const IntroV2: React.FC = () => (
  <KineticText
    duration={220}
    gap={26}
    lines={[
      { segments: ["We all know zVEM."], from: 12, to: 62 },
      // 0.5 s of black.
      { segments: ["We are introducing ", { text: "ŠEzVEM.", accent: true }], from: 77, to: 140 },
      {
        segments: ["A system for individual monitoring of patients after hospitalization."],
        from: 94,
        to: 140,
        size: 42,
        weight: 400,
        color: "#b8bec6",
        stagger: 1.5,
      },
      // 0.5 s of black.
      { segments: ["In the comfort of ", { text: "your home!", accent: true }], from: 155, to: 214, size: 108, weight: 700, emphasis: true },
    ]}
  />
);
