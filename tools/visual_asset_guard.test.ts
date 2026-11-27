import { inspectVisualManifest } from "./visual_asset_guard.ts";

function fixture(anchor?: unknown): unknown {
	const frame: Record<string, unknown> = {
		row: 0,
		column: 0,
		bbox: [0, 10, 20, 114],
	};
	if (arguments.length > 0) frame.runtime_horizontal_mass_anchor = anchor;
	return {
		character_sheets: {
			test: {
				columns: 1,
				rows: 1,
				cell_size: [128, 128],
				frames: [frame],
			},
		},
	};
}

function expectRejected(anchor: unknown, label: string): void {
	const { errors } = inspectVisualManifest(fixture(anchor));
	if (!errors.some((error) => error.includes("runtime mass anchor is missing or invalid"))) {
		throw new Error(`${label} anchor must fail validation`);
	}
}

const valid = inspectVisualManifest(fixture(64));
if (valid.errors.length !== 0) throw new Error(`finite centered anchor should pass: ${valid.errors.join("; ")}`);
const missing = inspectVisualManifest(fixture());
if (!missing.errors.some((error) => error.includes("runtime mass anchor is missing or invalid"))) {
	throw new Error("missing anchor must fail validation");
}
expectRejected(undefined, "undefined");
expectRejected(null, "null");
expectRejected("64", "string");
expectRejected(Number.NaN, "NaN");
expectRejected(Number.POSITIVE_INFINITY, "infinite");
console.log("Visual asset guard tests passed: missing and non-finite anchors are rejected.");
