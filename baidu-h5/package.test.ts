import { describe, expect, test } from "bun:test";
import { inflateRawSync } from "node:zlib";
import { createDeflateZip, MAX_FILE_BYTES, validateOfflineSource, validatePackageFiles, type PackageFile } from "./package_lib.ts";

const sourceFiles: PackageFile[] = await Promise.all(["index.html", "game.js"].map(async (name) => ({
	name,
	bytes: new Uint8Array(await Bun.file(`${import.meta.dir}/${name}`).arrayBuffer()),
})));

function readZipEntries(bytes: Uint8Array): Array<{ name: string; method: number; content: Uint8Array }> {
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	let eocd = bytes.length - 22;
	while (eocd >= 0 && view.getUint32(eocd, true) !== 0x06054b50) eocd -= 1;
	if (eocd < 0) throw new Error("ZIP EOCD is missing");
	const count = view.getUint16(eocd + 10, true);
	let offset = view.getUint32(eocd + 16, true);
	const decoder = new TextDecoder();
	const entries: Array<{ name: string; method: number; content: Uint8Array }> = [];
	for (let i = 0; i < count; i += 1) {
		if (view.getUint32(offset, true) !== 0x02014b50) throw new Error("Invalid central directory header");
		const method = view.getUint16(offset + 10, true);
		const compressedSize = view.getUint32(offset + 20, true);
		const uncompressedSize = view.getUint32(offset + 24, true);
		const nameLength = view.getUint16(offset + 28, true);
		const extraLength = view.getUint16(offset + 30, true);
		const commentLength = view.getUint16(offset + 32, true);
		const localOffset = view.getUint32(offset + 42, true);
		const name = decoder.decode(bytes.subarray(offset + 46, offset + 46 + nameLength));
		const localNameLength = view.getUint16(localOffset + 26, true);
		const localExtraLength = view.getUint16(localOffset + 28, true);
		const dataOffset = localOffset + 30 + localNameLength + localExtraLength;
		const compressed = bytes.subarray(dataOffset, dataOffset + compressedSize);
		const content = new Uint8Array(inflateRawSync(compressed));
		if (content.length !== uncompressedSize) throw new Error(`Bad uncompressed length for ${name}`);
		entries.push({ name, method, content });
		offset += 46 + nameLength + extraLength + commentLength;
	}
	return entries;
}

describe("Baidu H5 package", () => {
	test("includes one root entry and only bounded static files", () => {
		expect(validatePackageFiles(sourceFiles)).toEqual([]);
		expect(validateOfflineSource(sourceFiles)).toEqual([]);
		expect(sourceFiles.every((file) => file.bytes.length < MAX_FILE_BYTES)).toBe(true);
	});

	test("writes a deterministic UTF-8 Deflate ZIP with exact contents", () => {
		const first = createDeflateZip(sourceFiles);
		const second = createDeflateZip(sourceFiles);
		expect([...first]).toEqual([...second]);
		const entries = readZipEntries(first);
		expect(entries.map((entry) => entry.name)).toEqual(["index.html", "game.js"]);
		expect(entries.every((entry) => entry.method === 8)).toBe(true);
		expect(entries[0]!.content).toEqual(sourceFiles.find((file) => file.name === "index.html")!.bytes);
		expect(entries[1]!.content).toEqual(sourceFiles.find((file) => file.name === "game.js")!.bytes);
	});

	test("rejects traversal, over-size files, and forbidden APIs", () => {
		expect(validatePackageFiles([...sourceFiles, { name: "../escape.js", bytes: new Uint8Array([1]) }]).length).toBeGreaterThan(0);
		expect(validatePackageFiles(sourceFiles.map((file) => file.name === "game.js" ? { ...file, bytes: new Uint8Array(MAX_FILE_BYTES + 1) } : file)).length).toBeGreaterThan(0);
		expect(validateOfflineSource([{ name: "bad.js", bytes: new TextEncoder().encode("fetch('https://example.com')") }])).toContain("bad.js contains absolute HTTP(S) URL");
	});

	test("exposes the complete play and recovery loop with two state-changing actions", () => {
		const html = new TextDecoder().decode(sourceFiles[0]!.bytes);
		const js = new TextDecoder().decode(sourceFiles[1]!.bytes);
		for (const phrase of ["开始守夜", "击退来犯的倭寇", "守夜结束", "再守一夜"]) expect(html + js).toContain(phrase);
		for (const action of ["function triggerDash", "function attack", "function finishRun", "function beginRun"]) expect(js).toContain(action);
		expect(js).toContain("state.hp -= 1");
		expect(js).toContain("score += killed.length");
	});

	test("keeps controls outside the lower webview strip and native back gesture", () => {
		const html = new TextDecoder().decode(sourceFiles[0]!.bytes);
		expect(html).toContain("#stick { width: 132px; height: 132px; left: 72px; bottom: 110px; }");
		expect(html).toContain("#attack { right: 24px; bottom: 120px;");
		expect(html).toContain("#auto { right: 24px; top: 88px;");
		expect(html).toContain("viewport-fit=cover");
		expect(html).toContain("minimum-scale=1");
		expect(html).toContain("top: max(env(safe-area-inset-top), 44px)");
		expect(html).toContain("@media (orientation: landscape)");
		expect(html).not.toContain("serviceWorker");
		expect(html).not.toContain("requestFullscreen");
	});
});
