// Shared design tokens. Readout colours follow the reference monitor UI
// (theme.css of the PATI api /ui/); warning is pushed to orange per the brief.
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";

const inter = loadInter("normal", { weights: ["300", "400", "500", "600", "700"], subsets: ["latin", "latin-ext"] });
const mono = loadMono("normal", { weights: ["400", "500"], subsets: ["latin", "latin-ext"] });

export const theme = {
  font: `${inter.fontFamily}, system-ui, sans-serif`,
  mono: `${mono.fontFamily}, ui-monospace, monospace`,
  brand: "#1e9e6a",
  accent: "#0f766e",
  pageBg: "#0e1013",
  surface: "#ffffff",
  text: "#16191d",
  text2: "#4a525c",
  muted: "#7a838e",
  hairline: "rgba(22, 25, 29, 0.08)",
  readoutSurface: "#16191d",
  readoutText: "#e8eaed",
  readoutSecondary: "#a9b0b8",
  readoutMuted: "#737b85",
  normal: "#4ade80",
  warning: "#fb923c",
  critical: "#ef4444",
};

export const W = 1920;
export const H = 1080;
export const FPS = 30;
