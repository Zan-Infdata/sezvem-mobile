import React from "react";
import { Composition, Folder } from "remotion";
import { SezvemPromo } from "./Video";
import { TOTAL } from "./timeline";
import { FPS, H, W } from "./theme";
import { SceneV2Preview, SezvemPromoV2, V2_TOTAL } from "./v2/VideoV2";
import timelineV2 from "./v2/timeline.json";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="SezvemPromo" component={SezvemPromo} durationInFrames={TOTAL} fps={FPS} width={W} height={H} />
    <Composition id="SezvemPromoV2" component={SezvemPromoV2} durationInFrames={V2_TOTAL} fps={FPS} width={W} height={H} />
    <Folder name="V2-scenes">
      {timelineV2.scenes.map((s) => (
        <Composition
          key={s.id}
          id={`V2-${s.id}`}
          component={SceneV2Preview}
          defaultProps={{ id: s.id }}
          durationInFrames={s.duration}
          fps={FPS}
          width={W}
          height={H}
        />
      ))}
    </Folder>
  </>
);
