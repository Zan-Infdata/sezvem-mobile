// v2 scene "rise" (200 frames): the same live readout, continuing in simulated time,
// as the heart rate climbs through the warning and critical demo thresholds.
import React from "react";
import { MonitorStage } from "./monitor/MonitorStage";
import { RISE_SIM_START } from "./monitor/sim";

export const RiseV2: React.FC = () => <MonitorStage simStart={RISE_SIM_START} duration={200} zoom={[0.95, 1.02]} drift={10} />;
