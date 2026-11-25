import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

const ROOT = join(import.meta.dir, "..");
const SOURCE = join(ROOT, "game/assets/ui/menu_backdrop.png");
const OUTPUT = join(ROOT, "game/assets/ui/icon_app_512.png");

mkdirSync(dirname(OUTPUT), { recursive: true });

const filters = [
  "crop=720:720:280:0",
  "scale=512:512:flags=neighbor",
  "drawbox=x=10:y=10:w=492:h=492:color=0xe8d8b6:t=4",
  "drawbox=x=14:y=14:w=484:h=484:color=0x081014:t=4",
].join(",");

const result = Bun.spawnSync(
  [
    "ffmpeg",
    "-hide_banner",
    "-loglevel",
    "error",
    "-i",
    SOURCE,
    "-vf",
    filters,
    "-frames:v",
    "1",
    "-y",
    OUTPUT,
  ],
  { stdout: "inherit", stderr: "inherit" },
);

if (result.exitCode !== 0) {
  throw new Error(`ffmpeg failed with exit code ${result.exitCode}`);
}

console.log(`wrote ${OUTPUT}`);
