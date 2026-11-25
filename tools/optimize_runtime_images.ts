import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, extname, join, relative } from "node:path";
import sharp from "sharp";

const ROOT = join(import.meta.dir, "..");
const GAME = join(ROOT, "game");
const ASSETS = join(GAME, "assets");
const CHECK = process.argv.includes("--check");
const UPDATE_REFS = process.argv.includes("--update-references");

const INCLUDE_DIRS = [
  "ui/controls",
  "fx/jeff_fx",
  "units/forge",
  "units/towers",
];

const INCLUDE_FILES = [
  "ui/menu_backdrop.png",
  "ui/menu_clouds.png",
  "ui/menu_waves.png",
  "ui/menu_beacon.png",
  "ui/panel_dark.png",
  "ui/watch_cursor.png",
];

const LOSSY = new Map([
  ["ui/panel_dark.png", { quality: 92, alphaQuality: 100 }],
]);

const REF_ROOTS = ["scripts", "data", "scenes"].map((path) => join(GAME, path));
const REF_EXCLUDES = [
  /[\\/]tests[\\/]/,
  /[\\/]scripts[\\/]dev[\\/]/,
  /preview\.tscn$/,
  /character_templates\.json$/,
  /actors\.json$/,
  /credits\.json$/,
  /project_meta\.json$/,
];

function walkPngs(path: string): string[] {
  const result: string[] = [];
  for (const entry of readdirSync(path, { withFileTypes: true })) {
    const child = join(path, entry.name);
    if (entry.isDirectory()) result.push(...walkPngs(child));
    else if (extname(entry.name).toLowerCase() === ".png") result.push(child);
  }
  return result;
}

const sources = new Set<string>();
for (const directory of INCLUDE_DIRS) {
  const absolute = join(ASSETS, directory);
  if (existsSync(absolute)) {
    for (const file of walkPngs(absolute)) sources.add(file);
  }
}
for (const file of INCLUDE_FILES) {
  const absolute = join(ASSETS, file);
  if (!existsSync(absolute)) {
    throw new Error(`Missing optimized image source: ${absolute}`);
  }
  sources.add(absolute);
}

function targetFor(source: string): string {
  return source.replace(/\.png$/i, ".webp");
}

let sourceBytes = 0;
let targetBytes = 0;
const generated: Array<{ source: string; target: string; before: number; after: number }> = [];

for (const source of [...sources].sort()) {
  const target = targetFor(source);
  const relativeSource = relative(ASSETS, source).replaceAll("\\", "/");
  const lossy = LOSSY.get(relativeSource);
  const before = statSync(source).size;
  sourceBytes += before;
  const pipeline = sharp(source);
  const output = await pipeline
    .webp(
      lossy
        ? {
            quality: lossy.quality,
            alphaQuality: lossy.alphaQuality,
            effort: 6,
            smartSubsample: true,
          }
        : { lossless: true, effort: 6, alphaQuality: 100 },
    )
    .toBuffer();

  if (CHECK) {
    if (!existsSync(target)) {
      throw new Error(`Missing generated image: ${target}. Run \`bun run assets:images\`.`);
    }
    if (!readFileSync(target).equals(output)) {
      throw new Error(
        `Generated image is stale: ${relative(ROOT, target)}. Run \`bun run assets:images\`.`,
      );
    }
    const sourceMetadata = await sharp(source).metadata();
    const targetMetadata = await sharp(target).metadata();
    if (
      sourceMetadata.width !== targetMetadata.width ||
      sourceMetadata.height !== targetMetadata.height
    ) {
      throw new Error(`Image dimensions changed: ${relativeSource}`);
    }
    if (targetMetadata.format !== "webp") {
      throw new Error(`Not a WebP image: ${target}`);
    }
    const after = statSync(target).size;
    targetBytes += after;
    generated.push({ source, target, before, after });
    continue;
  }

  await Bun.write(target, output);
  const after = output.length;
  targetBytes += after;
  generated.push({ source, target, before, after });
}

const refFiles: string[] = [];
function walkRefs(path: string): void {
  if (REF_EXCLUDES.some((pattern) => pattern.test(path))) return;
  for (const entry of readdirSync(path, { withFileTypes: true })) {
    const child = join(path, entry.name);
    if (REF_EXCLUDES.some((pattern) => pattern.test(child))) continue;
    if (entry.isDirectory()) walkRefs(child);
    else if (/\.(gd|tscn|tres|json)$/.test(entry.name)) refFiles.push(child);
  }
}
for (const root of REF_ROOTS) walkRefs(root);

const replacements = generated
  .map(({ source, target }) => ({
    png: `res://${relative(GAME, source).replaceAll("\\", "/")}`,
    webp: `res://${relative(GAME, target).replaceAll("\\", "/")}`,
  }))
  .sort((left, right) => right.png.length - left.png.length);

let changedRefs = 0;
for (const file of refFiles) {
  const original = readFileSync(file, "utf8");
  let updated = original;
  for (const replacement of replacements) {
    if (updated.includes(replacement.png)) {
      updated = updated.replaceAll(replacement.png, replacement.webp);
    }
  }
  if (updated !== original) {
    if (UPDATE_REFS) {
      await Bun.write(file, updated);
      changedRefs += 1;
      console.log(`refs: ${relative(ROOT, file)}`);
    } else {
      throw new Error(
        `Stale PNG reference in ${relative(ROOT, file)}; run \`bun run assets:images -- --update-references\` once.`,
      );
    }
  }
}

const saved = sourceBytes - targetBytes;
const percent = sourceBytes === 0 ? 0 : (saved / sourceBytes) * 100;
console.log(
  `${CHECK ? "image check" : "image optimize"}: ${sources.size} files ${sourceBytes} -> ${targetBytes} bytes (${percent.toFixed(1)}% smaller)`,
);
if (UPDATE_REFS) console.log(`updated reference files: ${changedRefs}`);

if (CHECK && !UPDATE_REFS) {
  for (const { source, before, after } of generated) {
    if (after > before * 1.1) {
      throw new Error(
        `WebP output is unexpectedly larger: ${relative(ROOT, source)} (${before} -> ${after})`,
      );
    }
  }
}
