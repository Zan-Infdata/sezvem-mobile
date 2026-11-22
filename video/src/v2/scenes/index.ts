// Scene registry for v2: timeline id -> component. Owned by the lead; scene owners edit only their own file.
import React from "react";
import { IntroV2 } from "./IntroV2";
import { PairingV2 } from "./PairingV2";
import { MonitorV2 } from "./MonitorV2";
import { IrregularV2 } from "./IrregularV2";
import { RiseV2 } from "./RiseV2";
import { DetectV2 } from "./DetectV2";
import { CriticalV2 } from "./CriticalV2";
import { GoodCardV2 } from "./GoodCardV2";
import { GoodV2 } from "./GoodV2";
import { PhilosophyV2 } from "./PhilosophyV2";
import { CustomizeV2 } from "./CustomizeV2";
import { FinaleV2 } from "./FinaleV2";

export const SCENES: Record<string, React.FC> = {
  intro: IntroV2,
  pairing: PairingV2,
  monitor: MonitorV2,
  irregular: IrregularV2,
  rise: RiseV2,
  detect: DetectV2,
  critical: CriticalV2,
  goodCard: GoodCardV2,
  good: GoodV2,
  philosophy: PhilosophyV2,
  customize: CustomizeV2,
  finale: FinaleV2,
};
