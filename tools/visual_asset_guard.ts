export type VisualManifest = {
	character_sheets: Record<string, {
		columns: number;
		rows: number;
		cell_size: [number, number];
		frames: Array<{
			row: number;
			column: number;
			bbox: [number, number, number, number];
			runtime_horizontal_mass_anchor?: number;
		}>;
	}>;
};

export function inspectVisualManifest(input: unknown): { sheetCount: number; frameCount: number; errors: string[] } {
	const errors: string[] = [];
	if (!input || typeof input !== "object" || !("character_sheets" in input)) {
		return { sheetCount: 0, frameCount: 0, errors: ["manifest is missing character_sheets"] };
	}
	const sheets = (input as { character_sheets?: unknown }).character_sheets;
	if (!sheets || typeof sheets !== "object" || Array.isArray(sheets)) {
		return { sheetCount: 0, frameCount: 0, errors: ["character_sheets must be an object"] };
	}

	let frameCount = 0;
	for (const [sheetName, unknownSheet] of Object.entries(sheets)) {
		if (!unknownSheet || typeof unknownSheet !== "object") {
			errors.push(`${sheetName}: sheet entry must be an object`);
			continue;
		}
		const sheet = unknownSheet as VisualManifest["character_sheets"][string];
		const [cellWidth, cellHeight] = Array.isArray(sheet.cell_size) ? sheet.cell_size : [];
		if (
			![sheet.columns, sheet.rows, cellWidth, cellHeight].every((value) => typeof value === "number" && Number.isFinite(value))
		) {
			errors.push(`${sheetName}: dimensions and cell size must be finite numbers`);
			continue;
		}
		if (!Number.isInteger(sheet.columns) || !Number.isInteger(sheet.rows) || sheet.columns <= 0 || sheet.rows <= 0) {
			errors.push(`${sheetName}: row and column counts must be positive integers`);
			continue;
		}
		if (cellWidth !== 128 || cellHeight !== 128) {
			errors.push(`${sheetName}: expected 128x128 runtime cells`);
		}
		if (!Array.isArray(sheet.frames)) {
			errors.push(`${sheetName}: frames must be an array`);
			continue;
		}
		if (sheet.frames.length !== sheet.columns * sheet.rows) {
			errors.push(`${sheetName}: frame count does not match ${sheet.columns}x${sheet.rows}`);
		}
		const rowAnchors = new Map<number, number[]>();
		for (const frame of sheet.frames) {
			frameCount += 1;
			if (!frame || typeof frame !== "object") {
				errors.push(`${sheetName}: frame entry must be an object`);
				continue;
			}
			const { row, column } = frame;
			const [x, y, width, height] = Array.isArray(frame.bbox) ? frame.bbox : [];
			if (
				![row, column, x, y, width, height].every((value) => typeof value === "number" && Number.isFinite(value))
			) {
				errors.push(`${sheetName}: frame position and bbox must contain finite numbers`);
				continue;
			}
			if (!Number.isInteger(row) || !Number.isInteger(column) || row < 0 || row >= sheet.rows || column < 0 || column >= sheet.columns) {
				errors.push(`${sheetName}: frame row and column must identify a cell`);
				continue;
			}
			if (width <= 0 || height <= 0 || x < column * cellWidth || y < row * cellHeight || x + width > (column + 1) * cellWidth || y + height > (row + 1) * cellHeight) {
				errors.push(`${sheetName} row=${row} frame=${column}: frame art crosses its cell`);
				continue;
			}
			if (Math.abs(y + height - (row * cellHeight + cellHeight - 4)) > 1) {
				errors.push(`${sheetName} row=${row} frame=${column}: feet drift from the row baseline`);
			}
			const anchor = frame.runtime_horizontal_mass_anchor;
			if (typeof anchor !== "number" || !Number.isFinite(anchor)) {
				errors.push(`${sheetName} row=${row} frame=${column}: runtime mass anchor is missing or invalid`);
				continue;
			}
			const anchors = rowAnchors.get(row) ?? [];
			anchors.push(anchor);
			rowAnchors.set(row, anchors);
			if (Math.abs(anchor - cellWidth / 2) > 1.5) {
				errors.push(`${sheetName} row=${row} frame=${column}: visual mass drifts from the frame center`);
			}
		}
		for (const [row, anchors] of rowAnchors) {
			if (anchors.length > 1 && Math.max(...anchors) - Math.min(...anchors) > 1.5) {
				errors.push(`${sheetName} row=${row}: runtime mass anchor drifts across animation frames`);
			}
		}
	}
	return { sheetCount: Object.keys(sheets).length, frameCount, errors };
}

if (import.meta.main) {
	const manifestPath = Bun.argv[2] ?? "pixel-art/full_composed_atlas/clean/manifest.json";
	const manifest = JSON.parse(await Bun.file(manifestPath).text());
	const result = inspectVisualManifest(manifest);
	if (result.errors.length > 0) {
		console.error(`Visual geometry guard failed (${result.errors.length}):`);
		for (const error of result.errors.slice(0, 40)) console.error(`- ${error}`);
		process.exit(1);
	}
	console.log(`Visual geometry guard passed: ${result.sheetCount} full-character sheets, ${result.frameCount} frames, 128x128 cells, shared foot baseline and centered visual mass.`);
}
