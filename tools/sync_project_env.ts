import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export type ProjectEnv = Record<string, string>;

const ROOT = join(import.meta.dir, "..");
const GAME = join(ROOT, "game");
const ENV_PATH = join(ROOT, ".env");
const GODOT_VERSION_PATH = join(GAME, ".godot-version");
const PROJECT_PATH = join(GAME, "project.godot");
const EXPORT_PRESETS_PATH = join(GAME, "export_presets.cfg");
const PROJECT_META_PATH = join(GAME, "data", "project_meta.json");

const REQUIRED_KEYS = [
  "APP_VERSION",
  "GODOT_VERSION",
  "GAME_SLUG",
  "GAME_NAME_ZH",
  "GAME_NAME_EN",
  "AUTHOR",
  "AUTHOR_EMAIL",
  "REPO_URL",
  "WEB_URL",
  "CF_PAGES_PROJECT",
  "CF_PAGES_DOMAIN",
  "APP_BUNDLE_ID",
  "APP_ICON",
  "COPYRIGHT_NOTICE",
] as const;

const GENERATED_FILES = [
  ".godot-version",
  "project.godot",
  "export_presets.cfg",
  "data/project_meta.json",
] as const;

export function parseDotEnv(text: string): ProjectEnv {
  const values: ProjectEnv = {};
  for (const rawLine of text.replace(/^\uFEFF/, "").split(/\r?\n/)) {
    let line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    if (line.startsWith("export ")) line = line.slice(7).trim();
    const separator = line.indexOf("=");
    if (separator <= 0) {
      throw new Error(`Invalid .env line: ${rawLine}`);
    }
    const key = line.slice(0, separator).trim();
    if (!/^[A-Z][A-Z0-9_]*$/.test(key)) {
      throw new Error(`Invalid .env key: ${key}`);
    }
    let value = line.slice(separator + 1).trim();
    if (value.startsWith("'")) {
      if (!value.endsWith("'") || value.length < 2) {
        throw new Error(`Unclosed single-quoted value for ${key}`);
      }
      value = value.slice(1, -1);
    } else if (value.startsWith('"')) {
      if (!value.endsWith('"') || value.length < 2) {
        throw new Error(`Unclosed double-quoted value for ${key}`);
      }
      value = value
        .slice(1, -1)
        .replace(/\\n/g, "\n")
        .replace(/\\r/g, "\r")
        .replace(/\\t/g, "\t")
        .replace(/\\"/g, '"')
        .replace(/\\\\/g, "\\");
    } else {
      value = value.replace(/\s+#.*$/, "").trim();
    }
    if (values[key] !== undefined) {
      throw new Error(`Duplicate .env key: ${key}`);
    }
    values[key] = value;
  }
  return values;
}

export function formatWindowsVersion(version: string): string {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(version);
  if (!match) {
    throw new Error(`APP_VERSION must be semver-like, got ${version}`);
  }
  return `${Number(match[1])}.${Number(match[2])}.${Number(match[3])}.0`;
}

export function formatAndroidVersionCode(version: string): number {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(version);
  if (!match) {
    throw new Error(`APP_VERSION must be semver-like, got ${version}`);
  }
  const [, major, minor, patch] = match.map(Number);
  const code = major * 10_000 + minor * 100 + patch;
  if (!Number.isSafeInteger(code) || code < 1 || code > 2_100_000_000) {
    throw new Error(`APP_VERSION cannot be encoded as an Android version code: ${version}`);
  }
  return code;
}

export function renderProjectMeta(env: ProjectEnv): string {
  const metadata = {
    schema_version: 1,
    generated_from: ".env",
    app: {
      version: env.APP_VERSION,
      godot_version: env.GODOT_VERSION,
      slug: env.GAME_SLUG,
      bundle_identifier: env.APP_BUNDLE_ID,
      icon: env.APP_ICON,
      names: {
        zh: env.GAME_NAME_ZH,
        en: env.GAME_NAME_EN,
      },
    },
    author: {
      name: env.AUTHOR,
      email: env.AUTHOR_EMAIL,
    },
    links: {
      repository: env.REPO_URL,
      web: env.WEB_URL,
    },
    cloudflare_pages: {
      project: env.CF_PAGES_PROJECT,
      domain: env.CF_PAGES_DOMAIN,
    },
    legal: {
      copyright_notice: env.COPYRIGHT_NOTICE,
    },
  };
  return `${JSON.stringify(metadata, null, 2)}\n`;
}

export function setProjectSetting(
  text: string,
  section: string,
  key: string,
  value: string,
): string {
  const lines = text.split("\n");
  let currentSection = "";
  let sectionStart = -1;
  let insertIndex = -1;

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const header = /^\[([^\]]+)\]$/.exec(line);
    if (header) {
      if (currentSection === section && insertIndex < 0) {
        insertIndex = index;
      }
      currentSection = header[1];
      if (currentSection === section) {
        sectionStart = index;
      }
      continue;
    }
    if (currentSection !== section) continue;
    if (line.startsWith(`${key}=`)) {
      lines[index] = `${key}=${value}`;
      return lines.join("\n");
    }
    if (line.trim() !== "") {
      insertIndex = index + 1;
    }
  }

  if (sectionStart < 0) {
    throw new Error(`Missing [${section}] section`);
  }
  if (insertIndex < 0) {
    insertIndex = sectionStart + 1;
  }
  lines.splice(insertIndex, 0, `${key}=${value}`);
  return lines.join("\n");
}

function setConfigLines(text: string, values: Record<string, string>): string {
  return text
    .split("\n")
    .map((line) => {
      const separator = line.indexOf("=");
      if (separator <= 0) return line;
      const key = line.slice(0, separator);
      return values[key] === undefined ? line : `${key}=${values[key]}`;
    })
    .join("\n");
}

function quoteGodot(value: string): string {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
}

function validateEnv(env: ProjectEnv): void {
  for (const key of REQUIRED_KEYS) {
    if (!env[key]) {
      throw new Error(`Missing required .env key: ${key}`);
    }
  }
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(env.APP_VERSION)) {
    throw new Error(`APP_VERSION must be semver-like, got ${env.APP_VERSION}`);
  }
  if (!/^\d+\.\d+\.\d+-[0-9A-Za-z.]+$/.test(env.GODOT_VERSION)) {
    throw new Error(`GODOT_VERSION must use a Godot release tag, got ${env.GODOT_VERSION}`);
  }
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(env.GAME_SLUG)) {
    throw new Error(`GAME_SLUG must be lowercase kebab-case, got ${env.GAME_SLUG}`);
  }
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(env.CF_PAGES_PROJECT)) {
    throw new Error(`CF_PAGES_PROJECT is invalid: ${env.CF_PAGES_PROJECT}`);
  }
  if (!/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/i.test(env.CF_PAGES_DOMAIN)) {
    throw new Error(`CF_PAGES_DOMAIN must be a hostname: ${env.CF_PAGES_DOMAIN}`);
  }
  for (const key of ["REPO_URL", "WEB_URL"] as const) {
    let url: URL;
    try {
      url = new URL(env[key]);
    } catch {
      throw new Error(`${key} must be an absolute URL`);
    }
    if (url.protocol !== "https:") {
      throw new Error(`${key} must use https`);
    }
  }
  if (new URL(env.WEB_URL).hostname !== env.CF_PAGES_DOMAIN) {
    throw new Error("WEB_URL host must match CF_PAGES_DOMAIN");
  }
  if (!/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(env.AUTHOR_EMAIL)) {
    throw new Error(`AUTHOR_EMAIL is invalid: ${env.AUTHOR_EMAIL}`);
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9.-]*$/.test(env.APP_BUNDLE_ID)) {
    throw new Error(`APP_BUNDLE_ID is invalid: ${env.APP_BUNDLE_ID}`);
  }
  if (!env.APP_ICON.startsWith("res://")) {
    throw new Error(`APP_ICON must be a res:// path, got ${env.APP_ICON}`);
  }
  const iconPath = join(GAME, env.APP_ICON.slice("res://".length));
  if (!existsSync(iconPath)) {
    throw new Error(`APP_ICON does not exist: ${iconPath}`);
  }
}

function expectedFiles(env: ProjectEnv): Map<string, string> {
  const project = readFileSync(PROJECT_PATH, "utf8");
  const presets = readFileSync(EXPORT_PRESETS_PATH, "utf8");

  let nextProject = setProjectSetting(
    project,
    "application",
    "config/name",
    quoteGodot(env.GAME_NAME_ZH),
  );
  nextProject = setProjectSetting(
    nextProject,
    "application",
    "config/version",
    quoteGodot(env.APP_VERSION),
  );
  nextProject = setProjectSetting(
    nextProject,
    "application",
    "config/icon",
    quoteGodot(env.APP_ICON),
  );

  const windowsVersion = formatWindowsVersion(env.APP_VERSION);
  const androidVersionCode = formatAndroidVersionCode(env.APP_VERSION);
  let nextPresets = setConfigLines(presets, {
    "application/file_version": quoteGodot(windowsVersion),
    "application/product_version": quoteGodot(windowsVersion),
    "version/code": String(androidVersionCode),
    "version/name": quoteGodot(env.APP_VERSION),
    "application/company_name": quoteGodot(env.AUTHOR),
    "application/product_name": quoteGodot(env.GAME_NAME_ZH),
    "application/file_description": quoteGodot(
      `${env.GAME_NAME_ZH} / ${env.GAME_NAME_EN} · ${env.AUTHOR} · ${env.REPO_URL}`,
    ),
    "application/copyright": quoteGodot(env.COPYRIGHT_NOTICE),
    "application/bundle_identifier": quoteGodot(env.APP_BUNDLE_ID),
    "application/short_version": quoteGodot(env.APP_VERSION),
    "application/version": quoteGodot(env.APP_VERSION),
    "html/export_icon": "true",
  });
  nextPresets = setProjectSetting(
    nextPresets,
    "preset.1.options",
    "application/icon",
    quoteGodot(env.APP_ICON),
  );
  nextPresets = setProjectSetting(
    nextPresets,
    "preset.1.options",
    "application/console_wrapper_icon",
    quoteGodot(env.APP_ICON),
  );
  nextPresets = setProjectSetting(
    nextPresets,
    "preset.2.options",
    "application/icon",
    quoteGodot(env.APP_ICON),
  );

  return new Map([
    [GODOT_VERSION_PATH, `${env.GODOT_VERSION}\n`],
    [PROJECT_PATH, nextProject],
    [EXPORT_PRESETS_PATH, nextPresets],
    [PROJECT_META_PATH, renderProjectMeta(env)],
  ]);
}

function displayPath(path: string): string {
  return path.startsWith(`${ROOT}/`) ? path.slice(ROOT.length + 1) : path;
}

function reportDifference(path: string, actual: string, expected: string): void {
  const actualLines = actual.split("\n");
  const expectedLines = expected.split("\n");
  const count = Math.max(actualLines.length, expectedLines.length);
  let lineNumber = 1;
  for (; lineNumber <= count; lineNumber += 1) {
    if (actualLines[lineNumber - 1] !== expectedLines[lineNumber - 1]) break;
  }
  console.error(`stale: ${displayPath(path)} (first difference at line ${lineNumber})`);
  const actualLine = actualLines[lineNumber - 1];
  const expectedLine = expectedLines[lineNumber - 1];
  if (actualLine !== undefined) console.error(`  actual:   ${actualLine}`);
  if (expectedLine !== undefined) console.error(`  expected: ${expectedLine}`);
}

function main(): void {
  const args = process.argv.slice(2);
  const unknown = args.filter((arg) => arg !== "--check" && arg !== "--write");
  if (unknown.length > 0) {
    console.error(`Unknown arguments: ${unknown.join(" ")}`);
    process.exit(1);
  }
  if (args.includes("--check") && args.includes("--write")) {
    console.error("Use --check or --write, not both.");
    process.exit(1);
  }
  const write = args.includes("--write");

  let env: ProjectEnv;
  try {
    env = parseDotEnv(readFileSync(ENV_PATH, "utf8"));
    validateEnv(env);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }

  const expected = expectedFiles(env);
  let stale = 0;
  for (const [path, content] of expected) {
    const current = existsSync(path) ? readFileSync(path, "utf8") : "";
    if (current === content) {
      console.log(`ok: ${displayPath(path)}`);
      continue;
    }
    stale += 1;
    if (write) {
      writeFileSync(path, content, "utf8");
      console.log(`wrote: ${displayPath(path)}`);
    } else {
      reportDifference(path, current, content);
    }
  }

  if (!write && stale > 0) {
    console.error(
      `\n${stale} generated file(s) are stale. Run: bun run tools/sync_project_env.ts --write`,
    );
    process.exit(1);
  }
  if (write && stale === 0) {
    console.log("All generated files already match .env.");
  }
}

if (import.meta.main) {
  main();
}
