import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

type IconEntry = { file: string; author: string; icon: string; slug: string };

const ROOT = join(import.meta.dir, "..");
const ICON_DIR = join(ROOT, "game/assets/icons/game_icons");
const MANIFEST = join(ROOT, "tools/game_icons_cards.json");
const BASE = "https://raw.githubusercontent.com/game-icons/icons/master";
const PAGE = "https://game-icons.net/1x1";

const authorSlug = (author: string): string =>
  author.toLowerCase().replace(/\s+/g, "-");

const entries = JSON.parse(readFileSync(MANIFEST, "utf8")) as IconEntry[];

for (const entry of entries) {
  const target = join(ICON_DIR, entry.file);
  if (existsSync(target)) {
    console.log(`skip ${entry.file}`);
    continue;
  }
  const url = `${BASE}/${authorSlug(entry.author)}/${entry.slug}.svg`;
  const response = await fetch(url, {
    headers: { "user-agent": "xingwangzhe/2026-game-entry icon sync" },
  });
  if (!response.ok) {
    throw new Error(`${response.status} ${url}`);
  }
  const svg = await response.text();
  if (!svg.trimStart().startsWith("<svg")) {
    throw new Error(`not an SVG: ${url}`);
  }
  writeFileSync(target, svg);
  console.log(`saved ${entry.file}`);
}

const rows = entries.map((entry) => {
  const author = authorSlug(entry.author);
  return `| \`${entry.file}\` | ${entry.icon} | ${entry.author} | ${PAGE}/${author}/${entry.slug}.html |`;
});

const attribution = `# game-icons.net attribution / 图标署名

These icons come from [game-icons.net](${PAGE.replace("/1x1", "/")}) and are
licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
The full license text is included in \`LICENSE-CC-BY-3.0.txt\`.

The project uses the original white-on-transparent SVGs as UI textures and
tints them gold or parchment at runtime. Geometry, paths, and author
attribution are unchanged. This use does not imply endorsement by the authors.

| Local file | Original icon | Author | Source |
| --- | --- | --- | --- |
| \`ui_lantern.svg\` | Asian lantern | Delapouite | https://game-icons.net/1x1/delapouite/asian-lantern.html |
| \`ui_watchtower.svg\` | Watchtower | Delapouite | https://game-icons.net/1x1/delapouite/watchtower.html |
| \`ui_scroll.svg\` | Scroll unfurled | Lorc | https://game-icons.net/1x1/lorc/scroll-unfurled.html |
| \`ui_feast.svg\` | Bowl of rice | Caro Asercion | https://game-icons.net/1x1/caro-asercion/bowl-of-rice.html |
| \`wpn_katana.svg\` | Katana | Delapouite | https://game-icons.net/1x1/delapouite/katana.html |
| \`wpn_spear.svg\` | Barbed Spear | Lorc | https://game-icons.net/1x1/lorc/barbed-spear.html |
| \`wpn_bow.svg\` | Bow arrow | Delapouite | https://game-icons.net/1x1/delapouite/bow-arrow.html |
| \`wpn_musket.svg\` | Musket | Skoll | https://game-icons.net/1x1/skoll/musket.html |
| \`wpn_shield.svg\` | Round shield | Willdabeast | https://game-icons.net/1x1/willdabeast/round-shield.html |
| \`wpn_dragon_lantern.svg\` | Dragon head | Faithtoken | https://game-icons.net/1x1/faithtoken/dragon-head.html |
| \`wpn_cannon.svg\` | Cannon | Lorc | https://game-icons.net/1x1/lorc/cannon.html |
| \`wpn_banner.svg\` | Tattered banner | Lorc | https://game-icons.net/1x1/lorc/tattered-banner.html |
${rows.join("\n")}

Machine-readable credit entries live in \`game/data/credits.json\`.
`;

writeFileSync(join(ICON_DIR, "ATTRIBUTION.md"), attribution);
console.log(`attribution rows: ${entries.length}`);
