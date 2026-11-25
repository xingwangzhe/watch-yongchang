import { readFileSync } from "node:fs";

type Point = [number, number];
type Rect = [number, number, number, number];
type Area = Record<string, unknown>;

const MAPS_PATH = new URL("../game/data/maps.json", import.meta.url);

const rect = (kind: string, value: Rect, extra: Record<string, unknown> = {}): Area => ({
  kind,
  rect: value,
  ...extra,
});

const terrain = (value: Rect, tiles: string[], extra: Record<string, unknown> = {}): Area =>
  rect("terrain", value, { tiles, ...extra });

const path = (points: Point[], width: number, tiles: string[]): Area => ({
  kind: "path",
  points,
  width,
  tiles,
});

const waterPath = (points: Point[], width: number): Area => ({
  kind: "water_path",
  points,
  width,
  tiles: ["water_deep_a", "water_deep_b"],
});

const patch = (
  center: Point,
  radius: number | [number, number],
  tiles: string[],
  salt: number,
): Area => ({ kind: "patch", center, radius, tiles, salt });

const building = (
  value: Rect,
  style: "house" | "shop" | "hall" | "watch" = "house",
  extra: Record<string, unknown> = {},
): Area => rect("building", value, { style, ...extra });

const grove = (
  value: Rect,
  density = 0.42,
  floorTile = "mud_grass",
): Area =>
  rect("grove", value, {
    density,
    floor_tile: floorTile,
  });

const props = (
  prop: string,
  value: Rect,
  density: number,
  solid = false,
): Area => rect("props", value, { prop, density, solid });

const bridge = (value: Rect): Area => rect("bridge", value);
const wall = (value: Rect): Area => rect("wall", value);
const tower = (value: Rect): Area => rect("tower", value);
const gate = (value: Rect): Area => rect("gate", value);
const waterGate = (value: Rect): Area => rect("water_gate", value);
const water = (value: Rect): Area =>
  rect("water", value, { tiles: ["water_deep_a", "water_deep_b"] });

function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let value = Math.imul(state ^ (state >>> 15), 1 | state);
    value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function randomInt(rng: () => number, min: number, max: number): number {
  return min + Math.floor(rng() * (max - min + 1));
}

function splitWithGaps(
  start: number,
  length: number,
  maxSize: number,
  minSize: number,
  rng: () => number,
): Point[] {
  if (length <= maxSize) return [[start, length]];
  const count = Math.max(2, Math.ceil((length + 1) / (maxSize + 1)));
  const usable = length - (count - 1);
  if (usable < minSize * count) return [[start, length]];
  const sizes = Array.from(
    { length: count },
    (_, index) => Math.floor(usable / count) + (index < usable % count ? 1 : 0),
  );
  for (let index = 0; index + 1 < sizes.length; index += 1) {
    if (rng() < 0.55 && sizes[index] > minSize && sizes[index + 1] < maxSize) {
      sizes[index] -= 1;
      sizes[index + 1] += 1;
    } else if (rng() < 0.35 && sizes[index + 1] > minSize && sizes[index] < maxSize) {
      sizes[index + 1] -= 1;
      sizes[index] += 1;
    }
  }
  const result: Point[] = [];
  let cursor = start;
  for (const size of sizes) {
    result.push([cursor, size]);
    cursor += size + 1;
  }
  return result;
}

type CellSet = Set<string>;

function cellKey(x: number, y: number): string {
  return `${x},${y}`;
}

function hashCell(x: number, y: number, salt: number): number {
  const value = x * 92837111 + y * 689287499 + salt * 283923481;
  return Math.abs(value) % 1000003;
}

function distanceToSegment(
  px: number,
  py: number,
  ax: number,
  ay: number,
  bx: number,
  by: number,
): number {
  const dx = bx - ax;
  const dy = by - ay;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared <= 0.000001) return Math.hypot(px - ax, py - ay);
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / lengthSquared));
  return Math.hypot(px - (ax + dx * t), py - (ay + dy * t));
}

function distanceToPolyline(point: Point, points: Point[]): number {
  let best = Number.POSITIVE_INFINITY;
  for (let index = 1; index < points.length; index += 1) {
    const [ax, ay] = points[index - 1];
    const [bx, by] = points[index];
    best = Math.min(best, distanceToSegment(point[0], point[1], ax, ay, bx, by));
  }
  return best;
}

/**
 * Mirrors MapRenderer._ribbon_cells so settlement lots cannot overlap a
 * winding road or canal even when its centreline runs through a block.
 */
function ribbonCells(points: Point[], width: number, salt: number, wobble: number): Point[] {
  if (points.length === 0) return [];
  const padding = Math.ceil(width * 0.5 + 1);
  let minX = points[0][0];
  let minY = points[0][1];
  let maxX = points[0][0];
  let maxY = points[0][1];
  for (const [x, y] of points) {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x);
    maxY = Math.max(maxY, y);
  }
  const minCellX = Math.floor(minX) - padding;
  const minCellY = Math.floor(minY) - padding;
  const maxCellX = Math.ceil(maxX) + padding;
  const maxCellY = Math.ceil(maxY) + padding;
  const halfWidth = Math.max(0.75, width * 0.5);
  const cells: Point[] = [];
  for (let y = minCellY; y <= maxCellY; y += 1) {
    for (let x = minCellX; x <= maxCellX; x += 1) {
      const distance = distanceToPolyline([x + 0.5, y + 0.5], points);
      const edgeNoise = (hashCell(x, y, salt) / 1000003 - 0.5) * wobble;
      if (distance <= halfWidth + edgeNoise) cells.push([x, y]);
    }
  }
  return cells;
}

function reserveCell(reserved: CellSet, x: number, y: number, margin = 0): void {
  for (let offsetY = -margin; offsetY <= margin; offsetY += 1) {
    for (let offsetX = -margin; offsetX <= margin; offsetX += 1) {
      reserved.add(cellKey(x + offsetX, y + offsetY));
    }
  }
}

function reserveRect(reserved: CellSet, value: Rect, margin = 0): void {
  const [x, y, width, height] = value;
  for (let localY = 0; localY < height; localY += 1) {
    for (let localX = 0; localX < width; localX += 1) {
      reserveCell(reserved, x + localX, y + localY, margin);
    }
  }
}

function reservePolyline(reserved: CellSet, points: Point[], radius: number): void {
  if (points.length === 0) return;
  let minX = points[0][0];
  let minY = points[0][1];
  let maxX = points[0][0];
  let maxY = points[0][1];
  for (const [x, y] of points) {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x);
    maxY = Math.max(maxY, y);
  }
  const padding = Math.ceil(radius + 1);
  for (let y = Math.floor(minY) - padding; y <= Math.ceil(maxY) + padding; y += 1) {
    for (let x = Math.floor(minX) - padding; x <= Math.ceil(maxX) + padding; x += 1) {
      if (distanceToPolyline([x + 0.5, y + 0.5], points) <= radius) {
        reserveCell(reserved, x, y, 1);
      }
    }
  }
}

function settlementReservations(
  areas: Area[],
  spawnLanes: Point[][],
  landmarks: Array<Record<string, unknown>>,
): CellSet {
  const reserved: CellSet = new Set();
  for (const area of areas) {
    const kind = String(area.kind ?? "");
    if (kind === "path" || kind === "water_path" || kind === "creek") {
      const points = (area.points ?? []) as Point[];
      const width = Number(area.width ?? (kind === "path" ? 4 : 6));
      const salt = kind === "path" ? 71 : 113;
      const wobble = kind === "path" ? 0.42 : 0.55;
      for (const [x, y] of ribbonCells(points, width, salt, wobble)) {
        reserveCell(reserved, x, y, 1);
      }
      continue;
    }
    if (
      area.rect &&
      [
        "bridge",
        "wall",
        "tower",
        "gate",
        "water_gate",
        "water",
        "road",
        "plaza",
        "building",
        "props",
        "grove",
        "reeds",
        "patch",
      ].includes(kind)
    ) {
      reserveRect(reserved, area.rect as Rect, kind === "building" ? 1 : 0);
    }
  }
  for (const lane of spawnLanes) {
    reservePolyline(reserved, lane, 2.5);
  }
  for (const landmark of landmarks) {
    const tile = landmark.tile as Point | undefined;
    if (tile) reserveCell(reserved, tile[0], tile[1], 3);
  }
  return reserved;
}

function rectIsFree(reserved: CellSet, value: Rect): boolean {
  const [x, y, width, height] = value;
  for (let localY = 0; localY < height; localY += 1) {
    for (let localX = 0; localX < width; localX += 1) {
      if (reserved.has(cellKey(x + localX, y + localY))) return false;
    }
  }
  return true;
}

type LotStyle = "house" | "shop" | "hall" | "watch";

function pickLotStyle(rng: () => number, width: number, height: number): LotStyle {
  const roll = rng();
  if (width <= 4 && height <= 5 && roll < 0.06) return "watch";
  if (width >= 5 && height >= 5 && roll < 0.14) return "hall";
  if (roll < 0.34) return "shop";
  return "house";
}

/**
 * Splits broad safe blocks into small courtyard lots. New buildings reserve
 * their footprint plus one alley cell, so later lots cannot fuse into a
 * featureless mega-roof.
 */
function addSettlementLots(
  areas: Area[],
  blocks: Rect[],
  rng: () => number,
  reserved: CellSet,
): void {
  for (const [blockX, blockY, blockWidth, blockHeight] of blocks) {
    if (blockWidth < 3 || blockHeight < 3) continue;
    const rows = splitWithGaps(blockY, blockHeight, 6, 3, rng);
    const columns = splitWithGaps(blockX, blockWidth, 7, 3, rng);
    for (const [rowY, rowHeight] of rows) {
      for (const [columnX, columnWidth] of columns) {
        let x = columnX;
        let y = rowY;
        let width = columnWidth;
        let height = rowHeight;
        if (width >= 5 && rng() < 0.24) {
          if (rng() < 0.5) x += 1;
          width -= 1;
        }
        if (height >= 5 && rng() < 0.22) {
          if (rng() < 0.5) y += 1;
          height -= 1;
        }
        const value: Rect = [x, y, width, height];
        if (width < 3 || height < 3 || !rectIsFree(reserved, value)) continue;
        const style = pickLotStyle(rng, width, height);
        const ridgeCount = style === "hall" && height >= 5 ? 2 : height >= 7 ? 2 : 1;
        areas.push(building(value, style, { ridge_count: ridgeCount }));
        reserveRect(reserved, value, 1);
      }
    }
  }
}

/**
 * Fills larger open hamlets after the structured rows have claimed the best
 * frontage lots. Candidate footprints still respect roads, water, spawn lanes,
 * landmark clearances, and the one-cell alley reserved around every building.
 */
function addScatteredLots(
  areas: Area[],
  region: Rect,
  targetCount: number,
  rng: () => number,
  reserved: CellSet,
): number {
  let placed = 0;
  const [regionX, regionY, regionWidth, regionHeight] = region;
  const maxAttempts = targetCount * 40;
  for (let attempt = 0; attempt < maxAttempts && placed < targetCount; attempt += 1) {
    const width = randomInt(rng, 3, Math.min(6, regionWidth));
    const height = randomInt(rng, 3, Math.min(6, regionHeight));
    const x = regionX + randomInt(rng, 0, regionWidth - width);
    const y = regionY + randomInt(rng, 0, regionHeight - height);
    const value: Rect = [x, y, width, height];
    if (!rectIsFree(reserved, value)) continue;
    const style = pickLotStyle(rng, width, height);
    const ridgeCount = style === "hall" && height >= 5 ? 2 : height >= 7 ? 2 : 1;
    areas.push(building(value, style, { ridge_count: ridgeCount }));
    reserveRect(reserved, value, 1);
    placed += 1;
  }
  return placed;
}

function cityLots(): Area[] {
  const blocks: Rect[] = [];
  const xBands: Point[] = [
    [6, 11],
    [18, 25],
    [34, 44],
    [54, 61],
    [69, 77],
    [83, 88],
  ];
  const yBands: Point[] = [
    [7, 27],
    [33, 51],
    [57, 75],
    [83, 103],
    [109, 127],
    [133, 152],
  ];
  for (const [x0, x1] of xBands) {
    for (const [y0, y1] of yBands) {
      blocks.push([x0, y0, x1 - x0 + 1, y1 - y0 + 1]);
    }
  }

  const rng = seededRandom(20261125);
  const result: Area[] = [];
  for (const [bx, by, bw, bh] of blocks) {
    const leftPad = bw <= 8 ? 1 : randomInt(rng, 1, 2);
    const rightPad = bw <= 8 ? 1 : randomInt(rng, 1, 2);
    const innerX = bx + leftPad;
    const innerY = by + 1;
    const innerW = bw - leftPad - rightPad;
    const innerH = bh - 2;
    if (innerW < 3 || innerH < 3) continue;

    const styleFor = (width: number, height: number): "house" | "shop" | "hall" | "watch" => {
      const roll = rng();
      if (width <= 4 && height <= 6 && roll < 0.12) return "watch";
      if (roll < 0.28) return "shop";
      if (roll < 0.43 && width >= 6 && height >= 5) return "hall";
      return "house";
    };
    const ridgesFor = (height: number, style: string): number => {
      if (style === "hall" && height >= 6) return 2;
      if (height >= 7) return 2;
      return 1;
    };
    const pushLot = (value: Rect, style: "house" | "shop" | "hall" | "watch"): void => {
      result.push(
        building(value, style, {
          ridge_count: ridgesFor(value[3], style),
        }),
      );
    };
    const pushCourtyard = (value: Rect): void => {
      if (value[2] < 3 || value[3] < 3 || rng() > 0.72) return;
      const prop = rng() < 0.62 ? "tree_a" : "bamboo";
      result.push(props(prop, value, prop === "tree_a" ? 0.18 : 0.22, true));
    };

    // 每个街区拆成 3–7 格深的院落尺度地块，中间留 1 格巷缝；
    // 不再让 15–17 格长的整条街坊变成一块看不到檐口的巨屋顶。
    const rows = splitWithGaps(innerY, innerH, 7, 4, rng);
    const columns = splitWithGaps(innerX, innerW, 7, 3, rng);
    for (const [rowY, rowH] of rows) {
      if (innerW >= 8 && rowH >= 5 && rng() < 0.10) {
        pushLot([innerX, rowY, innerW, rowH], rng() < 0.58 ? "hall" : "shop");
        continue;
      }
      for (const [colX, colW] of columns) {
        let x = colX;
        let y = rowY;
        let width = colW;
        let height = rowH;
        if (width >= 5 && rng() < 0.20) {
          if (rng() < 0.5) {
            x += 1;
            width -= 1;
          } else {
            width -= 1;
          }
        }
        if (height >= 5 && rng() < 0.16) {
          if (rng() < 0.5) y += 1;
          height -= 1;
        }
        if (width < 3 || height < 3) continue;
        if (rng() < 0.11) {
          pushCourtyard([x, y, width, height]);
          continue;
        }
        pushLot([x, y, width, height], styleFor(width, height));
      }
    }
  }
  return result;
}

function tidelandLayout(): Record<string, unknown> {
  const areas: Area[] = [
    terrain([0, 0, 120, 12], ["sand_b", "sand_c"]),
    terrain([0, 65, 120, 10], ["sand_a", "sand_b"]),
    patch([16, 24], [11, 9], ["salt_pan"], 11),
    patch([105, 25], [11, 10], ["salt_pan"], 13),
    patch([18, 43], [13, 9], ["mud_grass", "mud_grass_b"], 17),
    patch([64, 36], [24, 18], ["mud_a", "mud_b", "cracked_mud"], 23),
    patch([55, 62], [28, 9], ["cracked_mud", "mud_a"], 29),
    waterPath(
      [
        [34, 4],
        [32, 13],
        [36, 21],
        [31, 30],
        [35, 39],
        [32, 47],
        [37, 55],
        [33, 63],
        [41, 71],
        [49, 82],
      ],
      7,
    ),
    waterPath(
      [
        [87, 4],
        [85, 13],
        [89, 21],
        [86, 30],
        [90, 39],
        [86, 47],
        [89, 55],
        [84, 63],
        [78, 71],
        [70, 82],
      ],
      7,
    ),
    water([20, 43, 8, 5]),
    water([96, 35, 9, 5]),
    path(
      [
        [60, 3],
        [60, 12],
        [58, 20],
        [61, 28],
        [59, 36],
        [61, 44],
        [61, 48],
        [60, 56],
        [62, 64],
        [60, 72],
        [60, 82],
      ],
      4,
      ["earth_road_a", "earth_road_b"],
    ),
    path(
      [
        [3, 20],
        [16, 21],
        [25, 20],
        [33, 22],
        [42, 21],
        [51, 22],
        [60, 22],
        [71, 23],
        [80, 22],
        [90, 21],
        [101, 22],
        [116, 20],
      ],
      4,
      ["earth_road_a", "earth_road_b"],
    ),
    path(
      [
        [3, 48],
        [14, 47],
        [23, 46],
        [31, 48],
        [42, 47],
        [52, 49],
        [61, 48],
        [72, 47],
        [84, 48],
        [96, 47],
        [108, 46],
        [117, 48],
      ],
      4,
      ["earth_road_a", "earth_road_b"],
    ),
    path(
      [
        [5, 62],
        [18, 64],
        [30, 62],
        [42, 64],
        [53, 62],
        [60, 62],
        [69, 64],
        [80, 62],
        [91, 64],
        [105, 62],
        [116, 63],
      ],
      4,
      ["earth_road_a", "earth_road_b"],
    ),
    path(
      [
        [4, 32],
        [11, 31],
        [18, 30],
        [25, 31],
      ],
      3,
      ["earth_road_a", "earth_road_b"],
    ),
    wall([0, 69, 22, 3]),
    wall([96, 69, 24, 3]),
    bridge([27, 18, 14, 6]),
    bridge([81, 18, 14, 6]),
    bridge([26, 45, 16, 7]),
    bridge([81, 45, 16, 7]),
    bridge([27, 59, 13, 7]),
    bridge([80, 59, 13, 7]),
    building([65, 10, 5, 4], "watch"),
    building([12, 34, 7, 5], "hall"),
    building([23, 53, 6, 4], "shop"),
    building([103, 51, 6, 5], "shop"),
    building([88, 66, 5, 3], "house"),
    building([46, 66, 5, 3], "house"),
    grove([13, 10, 8, 7], 0.40),
    grove([44, 10, 8, 7], 0.42),
    grove([97, 10, 8, 7], 0.38),
    grove([11, 51, 8, 7], 0.46),
    grove([46, 29, 8, 9], 0.40),
    grove([103, 26, 9, 6], 0.42),
    grove([46, 55, 7, 5], 0.36, "mud_grass_b"),
    rect("reeds", [25, 6, 12, 9], {
      tiles: ["reed_bed", "mud_grass"],
      density: 0.30,
    }),
    rect("reeds", [76, 6, 12, 9], {
      tiles: ["reed_bed", "mud_grass"],
      density: 0.30,
    }),
    rect("reeds", [23, 67, 34, 6], {
      tiles: ["reed_bed", "mud_grass"],
      density: 0.24,
    }),
    props("barrel", [14, 39, 4, 2], 0.38),
    props("crate", [27, 59, 4, 2], 0.34),
    props("wood_pile", [20, 38, 4, 2], 0.42),
    props("mooring_post", [42, 52, 3, 2], 0.50),
    props("fish_trap", [6, 65, 12, 2], 0.30),
    props("fishing_boat", [86, 73, 16, 4], 0.18),
  ];

  const landmarks: Array<Record<string, unknown>> = [
    { name_zh: "北堤", name_en: "North Dike", tile: [60, 6], kind: "gate", color: "#e1b35a" },
    { name_zh: "潮沟", name_en: "Tide Creek", tile: [35, 30], kind: "water", color: "#69a6b1" },
    { name_zh: "盐坂", name_en: "Salt Pans", tile: [15, 22], kind: "place", color: "#d9c487" },
    { name_zh: "旧海塘", name_en: "Old Seawall", tile: [24, 71], kind: "gate", color: "#c08c54" },
    { name_zh: "外海", name_en: "Open Sea", tile: [60, 80], kind: "water", color: "#397987" },
  ];
  const spawnLanes: Point[][] = [
    [[4, 6], [28, 6], [48, 6], [72, 6], [116, 6]],
    [[4, 63], [24, 63], [46, 63], [76, 63], [116, 63]],
    [[4, 14], [4, 38], [4, 58], [4, 66]],
    [[116, 14], [116, 38], [116, 58], [116, 66]],
    [[61, 12], [61, 30], [61, 58], [61, 72]],
    [[20, 20], [20, 44], [20, 58]],
    [[99, 20], [99, 44], [99, 58]],
  ];
  const reserved = settlementReservations(areas, spawnLanes, landmarks);
  addSettlementLots(
    areas,
    [
      [7, 7, 17, 10],
      [42, 7, 15, 9],
      [70, 7, 12, 9],
      [97, 7, 18, 9],
      [5, 27, 22, 17],
      [31, 27, 13, 17],
      [48, 27, 10, 13],
      [73, 27, 14, 16],
      [96, 28, 20, 15],
      [6, 53, 16, 7],
      [27, 53, 10, 6],
      [44, 53, 12, 7],
      [70, 53, 12, 7],
      [93, 53, 15, 6],
      [5, 68, 20, 12],
      [26, 69, 14, 10],
      [42, 70, 12, 10],
      [56, 68, 15, 12],
      [72, 68, 14, 12],
      [96, 68, 20, 10],
    ],
    seededRandom(20261129),
    reserved,
  );
  addScatteredLots(areas, [5, 9, 110, 71], 26, seededRandom(20261133), reserved);

  return {
    world_tiles: [120, 84],
    base_tile: "sand_a",
    start_tile: [61, 48],
    highlands: [
      [0, 0, 120, 7],
      [0, 69, 120, 4],
      [3, 9, 8, 20],
      [110, 9, 7, 22],
    ],
    areas,
    landmarks,
    spawn_lanes: spawnLanes,
  };
}

function watergateLayout(): Record<string, unknown> {
  const areas: Area[] = [
    terrain([0, 0, 96, 17], ["mud_grass", "mud_grass_b"]),
    terrain([0, 143, 96, 17], ["mud_grass", "mud_grass_b"]),
    terrain([0, 17, 12, 126], ["mud_grass", "mud_grass_b"]),
    terrain([84, 17, 12, 126], ["mud_grass", "mud_grass_b"]),
    waterPath(
      [
        [16, 19],
        [80, 19],
        [80, 141],
        [16, 141],
        [16, 19],
      ],
      9,
    ),
    waterPath(
      [
        [36, 0],
        [36, 18],
        [35, 35],
        [36, 55],
        [36, 75],
        [35, 95],
        [36, 115],
        [36, 160],
      ],
      6,
    ),
    waterPath(
      [
        [61, 0],
        [61, 18],
        [60, 35],
        [61, 55],
        [61, 75],
        [60, 95],
        [61, 115],
        [61, 160],
      ],
      6,
    ),
    patch([23, 72], [5, 7], ["mud_grass", "reed_bed"], 37),
    patch([72, 100], [5, 8], ["mud_grass", "reed_bed"], 41),
    path(
      [
        [48, 3],
        [48, 18],
        [47, 28],
        [46, 40],
        [47, 52],
        [48, 64],
        [47, 76],
        [48, 88],
        [47, 100],
        [48, 116],
        [48, 128],
        [48, 140],
        [48, 158],
      ],
      6,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [4, 81],
        [16, 80],
        [24, 80],
        [34, 80],
        [48, 80],
        [62, 80],
        [72, 80],
        [84, 80],
        [92, 81],
      ],
      6,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [24, 32],
        [24, 44],
        [24, 56],
        [24, 70],
        [24, 80],
        [24, 96],
        [24, 108],
        [24, 124],
        [24, 128],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [72, 32],
        [72, 44],
        [72, 56],
        [72, 70],
        [72, 80],
        [72, 96],
        [72, 108],
        [72, 124],
        [72, 128],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [24, 36],
        [31, 35],
        [40, 36],
        [47, 36],
        [56, 35],
        [63, 36],
        [72, 36],
      ],
      3,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [24, 112],
        [31, 113],
        [40, 112],
        [48, 112],
        [56, 113],
        [63, 112],
        [72, 112],
      ],
      3,
      ["stone_road_a", "stone_road_b"],
    ),
    wall([20, 28, 56, 4]),
    wall([20, 128, 56, 4]),
    wall([20, 28, 4, 104]),
    wall([72, 28, 4, 104]),
    tower([20, 28, 5, 5]),
    tower([34, 28, 5, 5]),
    tower([58, 28, 5, 5]),
    tower([71, 28, 5, 5]),
    tower([20, 127, 5, 5]),
    tower([34, 127, 5, 5]),
    tower([58, 127, 5, 5]),
    tower([71, 127, 5, 5]),
    tower([20, 44, 4, 4]),
    tower([20, 94, 4, 4]),
    tower([72, 44, 4, 4]),
    tower([72, 94, 4, 4]),
    bridge([29, 44, 15, 7]),
    bridge([54, 44, 15, 7]),
    bridge([29, 77, 15, 7]),
    bridge([54, 77, 15, 7]),
    bridge([29, 109, 15, 7]),
    bridge([54, 109, 15, 7]),
    bridge([45, 14, 6, 17]),
    bridge([45, 126, 6, 18]),
    bridge([7, 78, 17, 7]),
    bridge([72, 78, 17, 7]),
    bridge([33, 14, 6, 16]),
    bridge([58, 14, 6, 16]),
    bridge([33, 128, 6, 17]),
    bridge([58, 128, 6, 17]),
    gate([45, 28, 6, 4]),
    gate([45, 128, 6, 4]),
    gate([20, 78, 4, 7]),
    gate([72, 78, 4, 7]),
    waterGate([33, 25, 6, 8]),
    waterGate([58, 25, 6, 8]),
    waterGate([33, 127, 6, 9]),
    waterGate([58, 127, 6, 9]),
    building([27, 40, 5, 4], "hall"),
    building([64, 38, 6, 4], "shop"),
    building([27, 53, 5, 6], "house"),
    building([64, 53, 6, 5], "house"),
    building([27, 88, 5, 5], "hall"),
    building([64, 88, 5, 5], "shop"),
    building([27, 117, 6, 4], "house"),
    building([64, 117, 5, 5], "house"),
    grove([25, 63, 5, 7], 0.40, "mud_grass"),
    grove([65, 63, 5, 7], 0.38, "mud_grass"),
    grove([25, 96, 5, 7], 0.44, "mud_grass"),
    grove([65, 96, 5, 7], 0.40, "mud_grass"),
    rect("reeds", [4, 22, 8, 18], {
      tiles: ["reed_bed", "mud_grass"],
      density: 0.34,
    }),
    rect("reeds", [84, 118, 8, 20], {
      tiles: ["reed_bed", "mud_grass"],
      density: 0.34,
    }),
    props("stone_lamp", [43, 72, 2, 2], 0.50),
    props("stone_lamp", [51, 72, 2, 2], 0.50),
    props("banner_ming", [43, 30, 8, 2], 0.24),
    props("banner_ming", [43, 126, 8, 2], 0.24),
    props("mooring_post", [41, 69, 3, 4], 0.46),
    props("wood_pile", [34, 119, 3, 2], 0.50),
    props("fishing_boat", [15, 22, 9, 4], 0.16),
    props("fishing_boat", [72, 136, 9, 4], 0.16),
  ];

  const landmarks: Array<Record<string, unknown>> = [
    { name_zh: "迎川门", name_en: "Yingchuan Gate", tile: [48, 29], kind: "gate", color: "#e1b35a" },
    { name_zh: "通市门", name_en: "Tongshi Gate", tile: [48, 130], kind: "gate", color: "#e1b35a" },
    { name_zh: "镇山门", name_en: "Zhenshan Gate", tile: [21, 81], kind: "gate", color: "#e1b35a" },
    { name_zh: "环海门", name_en: "Huanhai Gate", tile: [74, 81], kind: "gate", color: "#e1b35a" },
    { name_zh: "上河", name_en: "Upper Canal", tile: [36, 72], kind: "water", color: "#69a6b1" },
    { name_zh: "下河", name_en: "Lower Canal", tile: [61, 72], kind: "water", color: "#69a6b1" },
    { name_zh: "北水门", name_en: "North Water Gate", tile: [36, 27], kind: "water_gate", color: "#8dc3cb" },
    { name_zh: "南水门", name_en: "South Water Gate", tile: [36, 134], kind: "water_gate", color: "#8dc3cb" },
  ];
  const spawnLanes: Point[][] = [
    [[48, 4], [48, 14], [48, 27]],
    [[48, 148], [48, 158], [48, 132]],
    [[3, 81], [10, 81], [21, 81]],
    [[86, 81], [93, 81], [75, 81]],
    [[7, 20], [7, 60], [7, 100], [7, 140]],
    [[89, 20], [89, 60], [89, 100], [89, 140]],
    [[24, 40], [24, 72], [24, 104], [24, 124]],
    [[71, 40], [71, 72], [71, 104], [71, 124]],
    [[34, 47], [44, 47], [52, 47], [66, 47]],
    [[34, 112], [44, 112], [52, 112], [66, 112]],
  ];
  const reserved = settlementReservations(areas, spawnLanes, landmarks);
  addSettlementLots(
    areas,
    [
      [26, 34, 7, 9],
      [26, 52, 7, 20],
      [26, 86, 7, 18],
      [26, 117, 7, 9],
      [64, 34, 8, 9],
      [64, 52, 8, 20],
      [64, 86, 8, 18],
      [64, 117, 8, 9],
      [40, 34, 5, 9],
      [40, 52, 5, 20],
      [40, 86, 5, 18],
      [40, 117, 5, 9],
      [52, 34, 6, 9],
      [52, 52, 6, 20],
      [52, 86, 6, 18],
      [52, 117, 6, 9],
      [16, 4, 14, 10],
      [54, 4, 22, 10],
      [16, 146, 14, 8],
      [54, 146, 22, 8],
    ],
    seededRandom(20261131),
    reserved,
  );
  addScatteredLots(areas, [26, 32, 48, 97], 18, seededRandom(20261135), reserved);
  addScatteredLots(areas, [16, 4, 54, 10], 5, seededRandom(20261137), reserved);
  addScatteredLots(areas, [16, 146, 54, 9], 5, seededRandom(20261139), reserved);

  return {
    world_tiles: [96, 160],
    base_tile: "mud_grass",
    start_tile: [48, 116],
    highlands: [
      [0, 17, 12, 26],
      [0, 110, 12, 33],
      [84, 17, 12, 26],
      [84, 110, 12, 33],
    ],
    areas,
    landmarks,
    spawn_lanes: spawnLanes,
  };
}

function crossstreetLayout(): Record<string, unknown> {
  const areas: Area[] = [
    terrain([4, 4, 88, 152], ["earth_road_a", "earth_road_b", "gravel"]),
    water(
      [0, 0, 96, 4],
    ),
    water([0, 156, 96, 4]),
    water([0, 0, 4, 160]),
    water([92, 0, 4, 160]),
    waterPath(
      [
        [31, 0],
        [31, 24],
        [30, 48],
        [31, 72],
        [31, 96],
        [30, 120],
        [31, 160],
      ],
      5,
    ),
    waterPath(
      [
        [65, 0],
        [65, 24],
        [66, 48],
        [65, 72],
        [65, 96],
        [66, 120],
        [65, 160],
      ],
      5,
    ),
    patch([22, 18], [7, 7], ["earth_road_b", "gravel"], 43),
    patch([74, 118], [8, 8], ["earth_road_b", "gravel"], 47),
    path(
      [
        [49, 4],
        [49, 20],
        [50, 34],
        [48, 48],
        [50, 60],
        [50, 76],
        [50, 90],
        [49, 108],
        [50, 124],
        [49, 140],
        [49, 154],
      ],
      6,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [4, 79],
        [16, 78],
        [28, 80],
        [38, 78],
        [50, 79],
        [58, 80],
        [72, 78],
        [82, 80],
        [92, 79],
      ],
      6,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [4, 30],
        [16, 30],
        [28, 29],
        [40, 30],
        [50, 30],
        [60, 29],
        [72, 30],
        [82, 29],
        [92, 30],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [4, 54],
        [18, 54],
        [31, 53],
        [42, 54],
        [50, 54],
        [58, 53],
        [66, 54],
        [80, 54],
        [92, 54],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [4, 106],
        [16, 105],
        [28, 106],
        [40, 105],
        [50, 106],
        [60, 106],
        [72, 105],
        [82, 106],
        [92, 106],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [4, 130],
        [18, 130],
        [31, 131],
        [42, 130],
        [50, 130],
        [58, 131],
        [66, 130],
        [80, 130],
        [92, 130],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [15, 5],
        [15, 28],
        [14, 52],
        [15, 78],
        [15, 104],
        [14, 128],
        [15, 154],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    path(
      [
        [81, 5],
        [81, 28],
        [82, 52],
        [81, 78],
        [81, 104],
        [82, 128],
        [81, 154],
      ],
      4,
      ["stone_road_a", "stone_road_b"],
    ),
    wall([4, 4, 88, 3]),
    wall([4, 153, 88, 3]),
    wall([4, 4, 3, 152]),
    wall([89, 4, 3, 152]),
    tower([4, 4, 5, 5]),
    tower([87, 4, 5, 5]),
    tower([4, 151, 5, 5]),
    tower([87, 151, 5, 5]),
    bridge([29, 27, 7, 7]),
    bridge([63, 27, 7, 7]),
    bridge([29, 51, 7, 7]),
    bridge([63, 51, 7, 7]),
    bridge([28, 76, 8, 7]),
    bridge([62, 76, 8, 7]),
    bridge([29, 103, 7, 7]),
    bridge([63, 103, 7, 7]),
    bridge([29, 127, 7, 7]),
    bridge([63, 127, 7, 7]),
    bridge([29, 0, 6, 6]),
    bridge([63, 0, 6, 6]),
    bridge([29, 154, 6, 6]),
    bridge([63, 154, 6, 6]),
    bridge([46, 0, 6, 5]),
    bridge([46, 155, 6, 5]),
    bridge([0, 78, 6, 6]),
    bridge([90, 78, 6, 6]),
    gate([46, 4, 6, 3]),
    gate([46, 153, 6, 3]),
    gate([4, 78, 3, 6]),
    gate([89, 78, 3, 6]),
    waterGate([29, 4, 6, 5]),
    waterGate([63, 4, 6, 5]),
    waterGate([29, 151, 6, 5]),
    waterGate([63, 151, 6, 5]),
    ...cityLots(),
    grove([19, 16, 7, 7], 0.34, "earth_road_b"),
    grove([71, 40, 6, 6], 0.36, "earth_road_b"),
    grove([19, 89, 7, 7], 0.38, "earth_road_b"),
    grove([72, 89, 6, 6], 0.34, "earth_road_b"),
    grove([39, 35, 5, 7], 0.30, "earth_road_b"),
    props("stone_lamp", [43, 73, 2, 2], 0.50),
    props("stone_lamp", [55, 73, 2, 2], 0.50),
    props("stone_lamp", [43, 84, 2, 2], 0.50),
    props("stone_lamp", [55, 84, 2, 2], 0.50),
    props("banner_ming", [44, 70, 10, 2], 0.28),
    props("banner_ming", [44, 88, 10, 2], 0.28),
    props("mooring_post", [34, 72, 3, 2], 0.50),
    props("wood_pile", [51, 107, 3, 2], 0.46),
    props("barrel", [17, 46, 4, 2], 0.30),
    props("crate", [77, 97, 4, 2], 0.30),
  ];

  return {
    world_tiles: [96, 160],
    base_tile: "earth_road_a",
    start_tile: [50, 79],
    highlands: [
      [4, 4, 88, 3],
      [4, 153, 88, 3],
      [4, 4, 3, 152],
      [89, 4, 3, 152],
    ],
    areas,
    landmarks: [
      { name_zh: "十字街心", name_en: "Crossroads", tile: [50, 79], kind: "place", color: "#e1b35a" },
      { name_zh: "迎川门", name_en: "Yingchuan Gate", tile: [49, 5], kind: "gate", color: "#e1b35a" },
      { name_zh: "通市门", name_en: "Tongshi Gate", tile: [49, 154], kind: "gate", color: "#e1b35a" },
      { name_zh: "镇山门", name_en: "Zhenshan Gate", tile: [5, 81], kind: "gate", color: "#e1b35a" },
      { name_zh: "环海门", name_en: "Huanhai Gate", tile: [90, 81], kind: "gate", color: "#e1b35a" },
      { name_zh: "西渠桥市", name_en: "West Canal Market", tile: [32, 79], kind: "place", color: "#d9c487" },
      { name_zh: "东渠桥市", name_en: "East Canal Market", tile: [66, 79], kind: "place", color: "#d9c487" },
      { name_zh: "北市", name_en: "North Market", tile: [49, 30], kind: "place", color: "#d9c487" },
      { name_zh: "南市", name_en: "South Market", tile: [49, 130], kind: "place", color: "#d9c487" },
    ],
    spawn_lanes: [
      [[49, 4], [49, 16], [49, 29]],
      [[49, 154], [49, 140], [49, 131]],
      [[4, 81], [14, 81], [22, 81]],
      [[91, 81], [82, 81], [74, 81]],
      [[15, 20], [15, 60], [15, 100], [15, 140]],
      [[81, 20], [81, 60], [81, 100], [81, 140]],
      [[15, 40], [15, 70], [15, 100], [15, 130]],
      [[81, 40], [81, 70], [81, 100], [81, 130]],
      [[24, 54], [40, 54], [58, 54], [72, 54]],
      [[24, 106], [40, 106], [58, 106], [72, 106]],
    ],
  };
}

const source = JSON.parse(readFileSync(MAPS_PATH, "utf8"));
source.maps.tideland.layout = tidelandLayout();
source.maps.watergate.layout = watergateLayout();
source.maps.crossstreet.layout = crossstreetLayout();

await Bun.write(MAPS_PATH, `${JSON.stringify(source, null, 2)}\n`);
console.log(
  `maps regenerated: ${Object.keys(source.maps).length} definitions, ` +
    `${source.maps.crossstreet.layout.areas.length} crossstreet areas`,
);
