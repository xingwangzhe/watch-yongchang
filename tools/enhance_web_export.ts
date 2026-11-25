import { copyFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

type ProjectMeta = {
  app: {
    version: string;
    slug: string;
    icon: string;
    names: { zh: string; en: string };
  };
  author: { name: string; email: string };
  links: { repository: string; web: string };
  legal: { copyright_notice: string };
};

const ROOT = join(import.meta.dir, "..");
const WEB_DIR = join(ROOT, "game/build/web");
const INDEX_PATH = join(WEB_DIR, "index.html");
const META_PATH = join(ROOT, "game/data/project_meta.json");
const BACKDROP_PATH = join(ROOT, "game/assets/ui/menu_backdrop.png");
const ICON_PATH = join(ROOT, "game/assets/ui/icon_app_512.png");

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function runFfmpeg(args: string[]): void {
  const result = Bun.spawnSync(["ffmpeg", "-hide_banner", "-loglevel", "error", ...args], {
    stdout: "inherit",
    stderr: "inherit",
  });
  if (result.exitCode !== 0) {
    throw new Error(`ffmpeg failed with exit code ${result.exitCode}`);
  }
}

if (!existsSync(INDEX_PATH)) {
  throw new Error(`Missing exported Web HTML: ${INDEX_PATH}`);
}
if (!existsSync(META_PATH)) {
  throw new Error(`Missing generated metadata: ${META_PATH}`);
}

const meta = JSON.parse(readFileSync(META_PATH, "utf8")) as ProjectMeta;
const title = `${meta.app.names.zh} / ${meta.app.names.en}`;
const description =
  "《守望·永昌》是一款以明代沿海卫所文化为背景的 2D 割草生存 Roguelite，参加 2026 OSGJ 开源游戏开发大赛。";
const canonical = meta.links.web;

copyFileSync(ICON_PATH, join(WEB_DIR, "icon-512.png"));
runFfmpeg([
  "-i",
  BACKDROP_PATH,
  "-vf",
  "scale=1200:675:flags=neighbor,crop=1200:630:0:22",
  "-frames:v",
  "1",
  "-y",
  join(WEB_DIR, "social-card.png"),
]);

const manifest = {
  name: meta.app.names.zh,
  short_name: "守望·永昌",
  description,
  lang: "zh-CN",
  start_url: "./",
  display: "standalone",
  background_color: "#081014",
  theme_color: "#081014",
  icons: [
    { src: "index.icon.png", sizes: "128x128", type: "image/png" },
    { src: "icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" },
  ],
};
writeFileSync(join(WEB_DIR, "site.webmanifest"), `${JSON.stringify(manifest, null, 2)}\n`);

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "VideoGame",
  name: meta.app.names.zh,
  alternateName: meta.app.names.en,
  description,
  url: canonical,
  image: `${canonical}/social-card.png`,
  softwareVersion: meta.app.version,
  applicationCategory: "Game",
  operatingSystem: "Web, Linux, Windows, macOS",
  author: {
    "@type": "Person",
    name: meta.author.name,
    email: meta.author.email,
    url: meta.links.repository,
  },
  codeRepository: meta.links.repository,
  license: `${meta.links.repository}/blob/main/LICENSE`,
  copyrightNotice: meta.legal.copyright_notice,
};

const tags = `
\t\t<meta name="description" content="${escapeHtml(description)}">
\t\t<meta name="author" content="${escapeHtml(meta.author.name)}">
\t\t<meta name="copyright" content="${escapeHtml(meta.legal.copyright_notice)}">
\t\t<meta name="application-name" content="${escapeHtml(meta.app.names.zh)}">
\t\t<meta name="theme-color" content="#081014">
\t\t<meta name="robots" content="index,follow">
\t\t<link rel="canonical" href="${escapeHtml(canonical)}/">
\t\t<link rel="manifest" href="site.webmanifest">
\t\t<link rel="icon" type="image/png" sizes="512x512" href="icon-512.png">
\t\t<meta property="og:type" content="website">
\t\t<meta property="og:site_name" content="${escapeHtml(meta.app.names.zh)}">
\t\t<meta property="og:title" content="${escapeHtml(title)}">
\t\t<meta property="og:description" content="${escapeHtml(description)}">
\t\t<meta property="og:url" content="${escapeHtml(canonical)}/">
\t\t<meta property="og:image" content="${escapeHtml(canonical)}/social-card.png">
\t\t<meta property="og:image:width" content="1200">
\t\t<meta property="og:image:height" content="630">
\t\t<meta property="og:locale" content="zh_CN">
\t\t<meta name="twitter:card" content="summary_large_image">
\t\t<meta name="twitter:title" content="${escapeHtml(title)}">
\t\t<meta name="twitter:description" content="${escapeHtml(description)}">
\t\t<meta name="twitter:image" content="${escapeHtml(canonical)}/social-card.png">
\t\t<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>
`;

let html = readFileSync(INDEX_PATH, "utf8");
html = html.replace(/<html\b[^>]*>/i, '<html lang="zh-CN">');
html = html.replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(title)}</title>`);
html = html.replace("</head>", `${tags}\t</head>`);
html = html.replace(/<meta name="description"[^>]*>\s*/gi, (match, offset) =>
  offset < html.indexOf(tags) ? "" : match,
);
writeFileSync(INDEX_PATH, html);

console.log(`enhanced ${INDEX_PATH}`);
