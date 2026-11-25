import { existsSync, readFileSync, readdirSync } from "node:fs";
import { extname, join } from "node:path";
import subsetFont from "subset-font";

const ROOT = join(import.meta.dir, "..");
const GAME = join(ROOT, "game");
const SOURCE_FONT = join(import.meta.dir, "fonts/LXGWWenKai-Regular-full.woff2");
const OUTPUT_FONT = join(GAME, "assets/fonts/LXGWWenKai-Regular.woff2");
const CHECK = process.argv.includes("--check");

const SCAN_ROOTS = [
  join(GAME, "scripts"),
  join(GAME, "scenes"),
  join(GAME, "data"),
];

const EXCLUDED_PATHS = [
  /[\\/]addons[\\/]/,
  /[\\/]tests[\\/]/,
  /[\\/]scripts[\\/]dev[\\/]/,
  /preview\.tscn$/,
  /character_templates\.json$/,
  /actors\.json$/,
];

const EXTRA_TEXT = [
  "守望·永昌",
  "WATCH · YONGCHANG",
  "xingwangzhe",
  "https://github.com/xingwangzhe/watch-yongchang",
  "https://2026shouwang.needhelp.icu",
  "－×÷＝≤≥≠→←↑↓◆◇○●■□▲△▼▽★☆©®™°％＋",
];

const ASCII = Array.from({ length: 95 }, (_, index) =>
  String.fromCodePoint(index + 32),
).join("");

const chars = new Set<string>([...ASCII, ...EXTRA_TEXT.join("")]);

function addString(value: string): void {
  for (const char of value) chars.add(char);
}

function decodeEscapes(value: string): string {
  return value.replace(
    /\\(u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|n|r|t|\\|"|')/g,
    (_match, escape: string) => {
      if (escape.startsWith("u")) {
        return String.fromCodePoint(Number.parseInt(escape.slice(1), 16));
      }
      if (escape.startsWith("x")) {
        return String.fromCodePoint(Number.parseInt(escape.slice(1), 16));
      }
      if (escape === "n") return "\n";
      if (escape === "r") return "\r";
      if (escape === "t") return "\t";
      return escape;
    },
  );
}

function stripLineComments(text: string): string {
  return text
    .split("\n")
    .map((line) => {
      let quote = "";
      for (let index = 0; index < line.length; index += 1) {
        const char = line[index];
        if (quote) {
          if (char === "\\") {
            index += 1;
          } else if (char === quote) {
            quote = "";
          }
        } else if (char === '"' || char === "'") {
          quote = char;
        } else if (char === "#") {
          return line.slice(0, index);
        }
      }
      return line;
    })
    .join("\n");
}

function collectQuotedStrings(text: string): void {
  const source = stripLineComments(text);
  const pattern = /"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)'/gs;
  for (const match of source.matchAll(pattern)) {
    addString(decodeEscapes(match[1] ?? match[2] ?? ""));
  }
}

function collectJsonStrings(value: unknown): void {
  if (typeof value === "string") {
    addString(value);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectJsonStrings(item);
    return;
  }
  if (value !== null && typeof value === "object") {
    for (const item of Object.values(value as Record<string, unknown>)) {
      collectJsonStrings(item);
    }
  }
}

function collectFile(path: string): void {
  const text = readFileSync(path, "utf8");
  if (extname(path) === ".json") {
    try {
      collectJsonStrings(JSON.parse(text));
      return;
    } catch {
      // Fall through to the literal scanner so a malformed generated file
      // cannot silently shrink the runtime character set.
    }
  }
  collectQuotedStrings(text);
}

function walk(path: string): void {
  if (EXCLUDED_PATHS.some((pattern) => pattern.test(path))) return;
  for (const entry of readdirSync(path, { withFileTypes: true })) {
    const child = join(path, entry.name);
    if (EXCLUDED_PATHS.some((pattern) => pattern.test(child))) continue;
    if (entry.isDirectory()) {
      walk(child);
    } else if (/\.(gd|tscn|tres|json|cfg)$/.test(entry.name)) {
      collectFile(child);
    }
  }
}

for (const root of SCAN_ROOTS) walk(root);

const envPath = join(ROOT, ".env");
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const match = /^[A-Z][A-Z0-9_]*=(.*)$/.exec(line.trim());
    if (match) addString(match[1].replace(/^(['"])(.*)\1$/, "$2"));
  }
}

const charset = [...chars]
  .sort((left, right) => left.codePointAt(0)! - right.codePointAt(0)!)
  .join("");

if (!existsSync(SOURCE_FONT)) {
  throw new Error(
    `Missing full font source: ${SOURCE_FONT}. Keep it outside game/ so it never enters the PCK.`,
  );
}

const source = readFileSync(SOURCE_FONT);
const subset = await subsetFont(source, charset, {
  targetFormat: "woff2",
  preserveNameIds: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
});

const cjkCount = [...chars].filter((char) => {
  const codePoint = char.codePointAt(0)!;
  return codePoint >= 0x4e00 && codePoint <= 0x9fff;
}).length;

if (CHECK) {
  if (!existsSync(OUTPUT_FONT)) {
    throw new Error(`Missing generated font: ${OUTPUT_FONT}`);
  }
  const current = readFileSync(OUTPUT_FONT);
  if (!current.equals(subset)) {
    throw new Error(
      "Generated font is stale. Run `bun run assets:font` and commit the result.",
    );
  }
  console.log(
    `font check ok: glyphs=${chars.size} cjk=${cjkCount} bytes=${current.length}`,
  );
} else {
  await Bun.write(OUTPUT_FONT, subset);
  console.log(
    `font subset: glyphs=${chars.size} cjk=${cjkCount} ${source.length} -> ${subset.length} bytes`,
  );
}
