// v2 scene "monitor" (135 frames): live heart rate from the paired WHOOP, steady around 80 bpm.
import React from "react";
import { MonitorStage } from "./monitor/MonitorStage";
import { MONITOR_SIM_START } from "./monitor/sim";

export const MonitorV2: React.FC = () => <MonitorStage simStart={MONITOR_SIM_START} duration={135} zoom={[0.9, 0.95]} drift={8} />;
