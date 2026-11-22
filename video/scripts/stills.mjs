// Renders half-size JPEG stills of one composition, plus a contact sheet-friendly naming.
// Usage: node scripts/stills.mjs <compositionId> <outDir> <frame> [frame...]
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import fs from "node:fs";
import path from "node:path";

const [id, outDir, ...frames] = process.argv.slice(2);
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
fs.mkdirSync(outDir, { recursive: true });
const serveUrl = await bundle({ entryPoint: path.join(root, "src/index.ts"), publicDir: path.join(root, "public") });
const composition = await selectComposition({ serveUrl, id });
for (const f of frames.map(Number)) {
  const output = path.resolve(outDir, `${id}-f${String(f).padStart(4, "0")}.jpg`);
  await renderStill({ serveUrl, composition, frame: f, output, imageFormat: "jpeg", scale: 0.5 });
  console.log(output);
}
