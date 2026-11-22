#!/usr/bin/env bun
/**
 * Build 64x64 unit sprite frames from two CC0 source sheets.
 *
 * Sources:
 * - daniloMattos, "Simple animated character", CC0 1.0
 *   https://opengameart.org/content/simple-animated-character
 * - sebshady, "Samurai Sprites", CC0 1.0
 *   https://opengameart.org/content/samurai-sprites
 *
 * Run once: cd tools && bun install
 * Then:     bun tools/process_cc0_sprites.ts
 */
import sharp from "sharp";
import { mkdir, readdir, unlink } from "node:fs/promises";
import { join, resolve } from "node:path";

type RGBA = [number, number, number, number];
type Canvas = { data: Buffer; w: number; h: number };

const ROOT = resolve(import.meta.dir, "..");
const SORA = join(ROOT, "generated/sprites_thirdparty/raw/danilomattos");
const SAMURAI = join(ROOT, "generated/sprites_thirdparty/raw/sebshady/samurai.png");
const OUT = join(ROOT, "game/assets/units");

const C = (hex: string, a = 255): RGBA => {
	const h = hex.replace("#", "");
	return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), a];
};

const PALETTES: Record<string, string[]> = {
	xiangyong: ["#2a2018", "#3d2d20", "#543b29", "#6d4f33", "#86653f", "#9d7c51", "#b59568", "#cbb080", "#ddc99a", "#eee0bc"],
	gongshou: ["#1c271b", "#283825", "#394f30", "#4c673f", "#5e7e4d", "#76965f", "#90af77", "#aac691", "#c4dbb0", "#e0edd3"],
	longdeng: ["#38120f", "#551a14", "#731e18", "#92261d", "#b13123", "#cf4c2c", "#e47637", "#efa94c", "#f3ce78", "#fbe7b3"],
	scout: ["#261812", "#38241a", "#4d3021", "#633e29", "#7a4d31", "#90603d", "#a67750", "#bd926c", "#d0b08c", "#e5d2af"],
	gun: ["#18191a", "#242526", "#343536", "#454646", "#565756", "#696967", "#7e7c77", "#96928a", "#b0aba1", "#cbc6bb"],
	ronin: ["#14131f", "#201d2d", "#2f2b3d", "#403b4e", "#544d61", "#6a6175", "#847989"],
	shield: ["#1d1911", "#2d2718", "#403722", "#55482c", "#6b5a38", "#836f46", "#9c8657"],
	chief: ["#1e0d0d", "#351211", "#501714", "#6e1d18", "#8f271e", "#b23627", "#ce5031"],
};

const INK = C("#1b1712");
const STEEL = C("#d8d6c8");
const STEEL_MID = C("#8b918e");
const STEEL_DARK = C("#394243");
const WOOD = C("#7a4c2b");
const WOOD_DARK = C("#3b2417");
const GOLD = C("#e2b34b");
const GOLD_HI = C("#f7df93");
const GOLD_DARK = C("#795016");
const RED = C("#b52d24");
const RED_HI = C("#e14b31");
const RED_DARK = C("#4d1210");

function px(c: Canvas, x: number, y: number, col: RGBA): void {
	x = Math.round(x); y = Math.round(y);
	if (x < 0 || y < 0 || x >= c.w || y >= c.h) return;
	const i = (y * c.w + x) * 4;
	const a = col[3] / 255;
	c.data[i] = Math.round(col[0] * a + c.data[i] * (1 - a));
	c.data[i + 1] = Math.round(col[1] * a + c.data[i + 1] * (1 - a));
	c.data[i + 2] = Math.round(col[2] * a + c.data[i + 2] * (1 - a));
	c.data[i + 3] = Math.max(c.data[i + 3], col[3]);
}

function rect(c: Canvas, x0: number, y0: number, x1: number, y1: number, col: RGBA): void {
	for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) px(c, x, y, col);
}

function line(c: Canvas, x0: number, y0: number, x1: number, y1: number, col: RGBA, w = 1): void {
	x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
	let dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
	let dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
	let err = dx + dy;
	for (;;) {
		for (let oy = 0; oy < w; oy++) px(c, x0, y0 + oy, col);
		if (x0 === x1 && y0 === y1) break;
		const e2 = 2 * err;
		if (e2 >= dy) { err += dy; x0 += sx; }
		if (e2 <= dx) { err += dx; y0 += sy; }
	}
}

function ellipse(c: Canvas, cx: number, cy: number, rx: number, ry: number, col: RGBA): void {
	for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
		for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
			const dx = (x - cx) / rx, dy = (y - cy) / ry;
			if (dx * dx + dy * dy <= 1.0) px(c, x, y, col);
		}
}

function ring(c: Canvas, cx: number, cy: number, rx: number, ry: number, col: RGBA): void {
	const steps = Math.ceil(Math.max(rx, ry) * 8);
	for (let i = 0; i < steps; i++) {
		const a = i / steps * Math.PI * 2;
		px(c, cx + Math.cos(a) * rx, cy + Math.sin(a) * ry, col);
	}
}

function poly(c: Canvas, pts: number[][], col: RGBA): void {
	let minY = 999, maxY = -999;
	for (const [, y] of pts) { minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
	for (let y = Math.floor(minY); y <= Math.ceil(maxY); y++) {
		const xs: number[] = [];
		for (let i = 0; i < pts.length; i++) {
			const [x1, y1] = pts[i], [x2, y2] = pts[(i + 1) % pts.length];
			if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) xs.push(x1 + (y - y1) * (x2 - x1) / (y2 - y1));
		}
		xs.sort((a, b) => a - b);
		for (let i = 0; i + 1 < xs.length; i += 2)
			for (let x = Math.ceil(xs[i]); x <= Math.floor(xs[i + 1]); x++) px(c, x, y, col);
	}
}

async function loadRaw(file: string): Promise<{ data: Buffer; width: number; height: number }> {
	const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	return { data, width: info.width, height: info.height };
}

function cropFrame(src: Buffer, sw: number, sh: number, fw: number, fi: number, dx = 0, dy = 0): Canvas {
	const out: Canvas = { data: Buffer.alloc(64 * 64 * 4), w: 64, h: 64 };
	for (let y = 0; y < sh; y++) for (let x = 0; x < fw; x++) {
		const sx = fi * fw + x;
		if (sx >= sw) continue;
		const si = (y * sw + sx) * 4;
		const di = ((y + dy) * 64 + x + dx) * 4;
		src.copy(out.data, di, si, si + 4);
	}
	return out;
}

function cleanSora(c: Canvas): void {
	for (let y = 56; y < 64; y++) for (let x = 0; x < 64; x++) {
		const i = (y * 64 + x) * 4;
		if (c.data[i + 3] < 8) continue;
		const r = c.data[i], g = c.data[i + 1], b = c.data[i + 2];
		if (c.data[i + 3] < 128 || (Math.max(r, g, b) - Math.min(r, g, b) < 8 && r > 70 && r < 240))
			c.data[i + 3] = 0;
	}
}

function recolor(src: Canvas, colors: string[], sora: boolean): Canvas {
	const out: Canvas = { data: Buffer.from(src.data), w: 64, h: 64 };
	for (let i = 0; i < out.data.length; i += 4) {
		if (out.data[i + 3] < 8) continue;
		const r = out.data[i], g = out.data[i + 1], b = out.data[i + 2];
		if (b > r + 10 && b >= g - 8) {
			const l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
			const idx = Math.max(0, Math.min(colors.length - 1, Math.round((l - 50) / 185 * (colors.length - 1))));
			const c = C(colors[idx]);
			out.data[i] = c[0]; out.data[i + 1] = c[1]; out.data[i + 2] = c[2];
		}
		if (sora) {
			const x = (i / 4) % 64, y = Math.floor(i / 4 / 64);
			if (x >= 17 && x <= 32 && y >= 12 && y <= 30 && r > 175 && g > 195 && b > 205) {
				out.data[i] = 232; out.data[i + 1] = 201; out.data[i + 2] = 154;
			}
		}
	}
	return out;
}

function dao(c: Canvas, f: number, attack: boolean): void {
	if (attack) {
		const a = [[26, 45, 11, 30], [25, 44, 8, 28], [27, 42, 9, 23], [28, 41, 17, 19], [26, 44, 12, 30]][f % 5];
		line(c, a[0], a[1], a[2], a[3], INK, 3);
		line(c, a[0], a[1], a[2], a[3], STEEL, 1);
		line(c, a[0] + 1, a[1] - 1, a[2] + 1, a[3] - 1, C("#fffbe5"), 1);
	} else {
		const a = [[25, 44, 8, 31], [24, 44, 7, 30], [25, 45, 9, 32], [26, 44, 11, 31]][f % 4];
		rect(c, 24, 42, 27, 46, WOOD_DARK);
		line(c, a[0], a[1], a[2], a[3], INK, 3);
		line(c, a[0], a[1], a[2], a[3], STEEL, 1);
	}
}

function bow(c: Canvas, attack: boolean): void {
	if (attack) {
		line(c, 18, 20, 12, 26, WOOD_DARK, 2); line(c, 12, 26, 11, 36, WOOD_DARK, 2); line(c, 11, 36, 14, 46, WOOD_DARK, 2);
		line(c, 18, 20, 17, 34, C("#d9c79d"), 1); line(c, 17, 34, 14, 46, C("#d9c79d"), 1);
		line(c, 12, 34, 34, 34, STEEL_MID, 1); line(c, 34, 33, 37, 34, RED, 1); line(c, 34, 35, 37, 34, RED_HI, 1);
	} else {
		line(c, 38, 24, 44, 30, WOOD_DARK, 2); line(c, 40, 26, 41, 38, WOOD_DARK, 2);
		line(c, 38, 24, 36, 40, C("#d9c79d"), 1); rect(c, 35, 38, 40, 46, WOOD_DARK);
		line(c, 36, 39, 39, 44, C("#c79a43"), 1);
	}
}

function matchlock(c: Canvas, f: number, attack: boolean): void {
	if (attack) {
		const y = f === 2 ? 33 : 34;
		rect(c, 5, y - 1, 32, y + 1, WOOD_DARK); rect(c, 5, y, 28, y, WOOD);
		rect(c, 7, y - 1, 10, y - 1, STEEL_DARK); line(c, 10, y - 2, 4, y - 2, STEEL_DARK, 1);
		line(c, 30, y + 2, 36, y + 6, WOOD_DARK, 3);
		if (f === 2) { px(c, 2, y - 1, RED_HI); px(c, 3, y - 2, GOLD_HI); px(c, 1, y, GOLD); px(c, 4, y - 1, RED); }
	} else {
		line(c, 12, 42, 33, 25, WOOD_DARK, 3); line(c, 14, 40, 33, 25, WOOD, 1);
		line(c, 33, 25, 38, 21, STEEL_DARK, 2); line(c, 33, 24, 38, 20, STEEL_MID, 1);
	}
}

function shield(c: Canvas, f: number): void {
	const bob = f % 2 ? 1 : 0;
	ellipse(c, 48, 38 + bob, 9, 10, INK); ellipse(c, 48, 37 + bob, 8, 9, C("#6c4d2b"));
	ring(c, 48, 37 + bob, 8, 9, C("#b28b50")); ring(c, 48, 37 + bob, 5, 6, C("#8c6638"));
	ellipse(c, 48, 37 + bob, 2, 2, C("#d4b56d")); line(c, 41, 33 + bob, 55, 41 + bob, C("#49301d"), 1);
}

function dragonHead(c: Canvas, f: number, attack: boolean): void {
	const x = attack ? (f === 2 || f === 3 ? 1 : 3) : (f % 2 ? 2 : 3);
	const y = f % 2 ? 1 : 0;
	line(c, 24, 43, 20 + x, 36 + y, WOOD_DARK, 3); line(c, 24, 42, 20 + x, 35 + y, WOOD, 1);
	poly(c, [[x + 17, y + 27], [x + 12, y + 25], [x + 6, y + 27], [x + 2, y + 31], [x + 5, y + 34], [x + 12, y + 34], [x + 18, y + 38]], INK);
	poly(c, [[x + 16, y + 28], [x + 11, y + 27], [x + 6, y + 29], [x + 4, y + 31], [x + 7, y + 32], [x + 13, y + 32], [x + 17, y + 35]], RED);
	poly(c, [[x + 15, y + 29], [x + 11, y + 28], [x + 7, y + 30], [x + 5, y + 31], [x + 10, y + 31], [x + 15, y + 31]], RED_HI);
	rect(c, x + 4, y + 31, x + 5, y + 32, C("#f1dfae")); px(c, x + 10, y + 29, GOLD_HI); px(c, x + 10, y + 30, GOLD);
	line(c, x + 14, y + 27, x + 17, y + 21, GOLD_DARK, 2); line(c, x + 16, y + 22, x + 20, y + 18, GOLD, 1);
	line(c, x + 18, y + 36, x + 24, y + 40, RED_DARK, 2); line(c, x + 19, y + 35, x + 25, y + 37, GOLD, 1);
	line(c, x + 20, y + 37, x + 24, y + 43, RED, 1);
}

function headband(c: Canvas, f: number): void {
	rect(c, 22, 14, 38, 15, RED_DARK); rect(c, 22, 14, 37, 14, RED);
	line(c, 38, 15, 45 + (f % 2), 18 + (f % 2), RED, 2); line(c, 38, 16, 44 + (f % 2), 21 + (f % 2), RED_DARK, 1);
}

function crestAndArmor(c: Canvas): void {
	rect(c, 21, 29, 26, 33, GOLD_DARK); rect(c, 22, 30, 26, 32, GOLD);
	rect(c, 37, 29, 43, 33, GOLD_DARK); rect(c, 37, 30, 42, 32, GOLD);
	line(c, 28, 18, 26, 10, GOLD_DARK, 2); line(c, 28, 17, 28, 8, GOLD, 1);
	line(c, 34, 18, 36, 10, GOLD_DARK, 2); line(c, 34, 17, 34, 8, GOLD, 1);
	rect(c, 27, 14, 35, 15, RED_HI); rect(c, 25, 34, 39, 35, C("#a63725")); line(c, 25, 36, 39, 36, GOLD_DARK, 1);
}

type Config = {
	id: string;
	base: "sora" | "samurai";
	palette: string[];
	kind: "dao" | "bow" | "dragon" | "headband" | "match" | "shield" | "ronin" | "chief";
	attack: "melee" | "ranged" | "samurai";
	attackFrames: number;
};

const CONFIGS: Config[] = [
	{ id: "xiangyong", base: "sora", palette: PALETTES.xiangyong, kind: "dao", attack: "melee", attackFrames: 5 },
	{ id: "gongshou", base: "sora", palette: PALETTES.gongshou, kind: "bow", attack: "ranged", attackFrames: 4 },
	{ id: "longdeng", base: "sora", palette: PALETTES.longdeng, kind: "dragon", attack: "melee", attackFrames: 5 },
	{ id: "wokou_scout", base: "sora", palette: PALETTES.scout, kind: "headband", attack: "melee", attackFrames: 5 },
	{ id: "wokou_gun", base: "sora", palette: PALETTES.gun, kind: "match", attack: "ranged", attackFrames: 4 },
	{ id: "wokou_ronin", base: "samurai", palette: PALETTES.ronin, kind: "ronin", attack: "samurai", attackFrames: 4 },
	{ id: "wokou_shield", base: "samurai", palette: PALETTES.shield, kind: "shield", attack: "samurai", attackFrames: 4 },
	{ id: "wokou_chief", base: "samurai", palette: PALETTES.chief, kind: "chief", attack: "samurai", attackFrames: 4 },
];

async function soraFrame(file: string, frameWidth: number, index: number): Promise<Canvas> {
	const src = await loadRaw(join(SORA, file));
	const c = cropFrame(src.data, src.width, src.height, frameWidth, index);
	cleanSora(c);
	return c;
}

async function samuraiFrame(index: number): Promise<Canvas> {
	const src = await loadRaw(SAMURAI);
	const row = Buffer.alloc(src.width * 48 * 4);
	for (let y = 0; y < 48; y++) for (let x = 0; x < 288; x++) {
		const si = ((2 * 48 + y) * src.width + x) * 4, di = (y * 288 + x) * 4;
		src.data.copy(row, di, si, si + 4);
	}
	return cropFrame(row, 288, 48, 48, index, 8, 16);
}

async function build(cfg: Config, attack: boolean, f: number): Promise<Canvas> {
	let c: Canvas;
	if (attack) {
		if (cfg.attack === "melee") c = await soraFrame("attack01.png", 80, f);
		else if (cfg.attack === "ranged") c = await soraFrame("ranged01.png", 80, f);
		else c = await samuraiFrame([0, 1, 2, 1][f % 4]);
	} else {
		c = cfg.base === "sora" ? await soraFrame("Walking_Right.png", 64, f) : await samuraiFrame([0, 1, 2, 1][f % 4]);
	}
	c = recolor(c, cfg.palette, cfg.base === "sora");
	if (cfg.kind === "dao") dao(c, f, attack);
	if (cfg.kind === "bow") bow(c, attack);
	if (cfg.kind === "dragon") dragonHead(c, f, attack);
	if (cfg.kind === "headband") headband(c, f);
	if (cfg.kind === "match") matchlock(c, f, attack);
	if (cfg.kind === "shield") shield(c, f);
	if (cfg.kind === "chief") crestAndArmor(c);
	return c;
}

async function save(c: Canvas, path: string): Promise<void> {
	await sharp(c.data, { raw: { width: 64, height: 64, channels: 4 } }).png().toFile(path);
}

async function trimFrames(dir: string, keep: number): Promise<void> {
	for (const name of await readdir(dir)) {
		const m = name.match(/^frame_(\d+)\.png$/);
		if (m && Number(m[1]) > keep) await unlink(join(dir, name));
	}
}

for (const cfg of CONFIGS) {
	const runDir = join(OUT, cfg.id, "run"), atkDir = join(OUT, cfg.id, "attack");
	await mkdir(runDir, { recursive: true }); await mkdir(atkDir, { recursive: true });
	await trimFrames(runDir, 4); await trimFrames(atkDir, cfg.attackFrames);
	for (let i = 0; i < 4; i++) {
		const c = await build(cfg, false, i);
		await save(c, join(runDir, `frame_${String(i + 1).padStart(2, "0")}.png`));
		if (i === 0) await save(c, join(OUT, cfg.id, "static.png"));
	}
	for (let i = 0; i < cfg.attackFrames; i++)
		await save(await build(cfg, true, i), join(atkDir, `frame_${String(i + 1).padStart(2, "0")}.png`));
	console.log(`[SPRITES] ${cfg.id}: run=4 attack=${cfg.attackFrames}`);
}
