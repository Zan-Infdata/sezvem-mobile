// The companion chat panel (after companion_chat_panel.dart), messages and a
// typing indicator. Messages appear immediately with a short pop.
import React from "react";
import { spring, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";
import { Kevin } from "./Kevin";

export type ChatMessage = {
  from: "kevin" | "user";
  text: string;
  /** Frame the message appears. */
  at: number;
  /** Frame a typing indicator starts before the message. */
  typingFrom?: number;
  urgent?: boolean;
};

export const ChatPanel: React.FC<{
  messages: ChatMessage[];
  openAt: number;
  closeAt?: number;
  style?: React.CSSProperties;
}> = ({ messages, openAt, closeAt = Infinity, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const open = spring({ frame: frame - openAt, fps, config: { damping: 18, stiffness: 160 } });
  const close = frame >= closeAt ? spring({ frame: frame - closeAt, fps, config: { damping: 200 }, durationInFrames: 10 }) : 0;
  const k = open * (1 - close);
  if (k <= 0.001) return null;
  return (
    <div
      style={{
        position: "absolute",
        background: theme.surface,
        borderRadius: 26,
        boxShadow: "0 20px 50px rgba(0,0,0,0.35)",
        overflow: "hidden",
        transformOrigin: "15% 100%",
        transform: `scale(${0.6 + 0.4 * k})`,
        opacity: k,
        display: "flex",
        flexDirection: "column",
        ...style,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "14px 16px", borderBottom: `1px solid ${theme.hairline}` }}>
        <div style={{ position: "relative", width: 34, height: 34, borderRadius: "50%", background: "#fff3e0", overflow: "hidden" }}>
          <Kevin x={17} y={33} radius={15} />
        </div>
        <div>
          <div style={{ fontSize: 17, fontWeight: 650, color: theme.text }}>Kevin</div>
          <div style={{ fontSize: 12.5, color: theme.muted }}>Your ŠEzVEM companion</div>
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 10, padding: 14 }}>
        {messages.map((m, i) => {
          if (frame >= m.at) return <Bubble key={i} m={m} />;
          if (m.typingFrom !== undefined && frame >= m.typingFrom) return <Typing key={i} from={m.from} />;
          return null;
        })}
      </div>
    </div>
  );
};

const Bubble: React.FC<{ m: ChatMessage }> = ({ m }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - m.at, fps, config: { damping: 16, stiffness: 200 } });
  const kevin = m.from === "kevin";
  return (
    <div
      style={{
        alignSelf: kevin ? "flex-start" : "flex-end",
        maxWidth: 300,
        padding: "10px 14px",
        borderRadius: 18,
        borderBottomLeftRadius: kevin ? 6 : 18,
        borderBottomRightRadius: kevin ? 18 : 6,
        background: m.urgent ? "#fdecec" : kevin ? "#eef1f4" : theme.accent,
        border: m.urgent ? `2px solid ${theme.critical}` : "none",
        color: kevin ? theme.text : "#fff",
        fontSize: 15.5,
        lineHeight: 1.36,
        opacity: s,
        transformOrigin: kevin ? "0% 100%" : "100% 100%",
        transform: `scale(${0.85 + 0.15 * s}) translateY(${(1 - s) * 10}px)`,
      }}
    >
      {m.urgent ? (
        <div style={{ fontSize: 12.5, fontWeight: 700, color: theme.critical, letterSpacing: 1, textTransform: "uppercase", marginBottom: 4 }}>
          ⚠ Safety escalation
        </div>
      ) : null}
      <span style={{ fontWeight: m.urgent ? 600 : 400 }}>{m.text}</span>
    </div>
  );
};

export const Typing: React.FC<{ from: "kevin" | "user" }> = ({ from }) => {
  const frame = useCurrentFrame();
  const kevin = from === "kevin";
  return (
    <div
      style={{
        alignSelf: kevin ? "flex-start" : "flex-end",
        display: "flex",
        gap: 5,
        padding: "13px 16px",
        borderRadius: 18,
        background: kevin ? "#eef1f4" : theme.accent,
      }}
    >
      {[0, 1, 2].map((i) => (
        <div
          key={i}
          style={{
            width: 8,
            height: 8,
            borderRadius: 4,
            background: kevin ? "#7a838e" : "#fff",
            transform: `translateY(${-Math.max(0, Math.sin((frame - i * 4) / 4)) * 5}px)`,
            opacity: 0.85,
          }}
        />
      ))}
    </div>
  );
};
