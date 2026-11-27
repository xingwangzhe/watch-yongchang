import { deflateRawSync } from "node:zlib";

export const MAX_FILE_BYTES = 10 * 1024 * 1024;
export const MAX_TOTAL_BYTES = 1024 * 1024 * 1024;
export const MAX_FILE_COUNT = 10_000;
export const REQUIRED_ROOT_FILES = ["index.html", "game.js"];

export interface PackageFile {
	name: string;
	bytes: Uint8Array;
}

export function crc32(bytes: Uint8Array): number {
	let crc = 0xffffffff;
	for (const byte of bytes) {
		crc ^= byte;
		for (let bit = 0; bit < 8; bit += 1) {
			crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
		}
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function u16(value: number): Uint8Array {
	const bytes = new Uint8Array(2);
	new DataView(bytes.buffer).setUint16(0, value, true);
	return bytes;
}

function u32(value: number): Uint8Array {
	const bytes = new Uint8Array(4);
	new DataView(bytes.buffer).setUint32(0, value >>> 0, true);
	return bytes;
}

function concat(chunks: Uint8Array[]): Uint8Array {
	const result = new Uint8Array(chunks.reduce((sum, chunk) => sum + chunk.length, 0));
	let offset = 0;
	for (const chunk of chunks) {
		result.set(chunk, offset);
		offset += chunk.length;
	}
	return result;
}

export function validatePackageFiles(files: PackageFile[]): string[] {
	const errors: string[] = [];
	if (files.length > MAX_FILE_COUNT) errors.push(`entry count ${files.length} exceeds ${MAX_FILE_COUNT}`);
	const names = files.map((file) => file.name);
	if (new Set(names).size !== names.length) errors.push("duplicate ZIP paths");
	for (const name of REQUIRED_ROOT_FILES) {
		if (names.filter((path) => path === name).length !== 1) errors.push(`ZIP must contain one root ${name}`);
	}
	if (names.filter((name) => name === "index.html").length !== 1) errors.push("ZIP must contain exactly one index.html entry");
	let total = 0;
	for (const file of files) {
		const name = file.name;
		if (!/^[a-z0-9._/-]+$/.test(name) || name.startsWith("/") || name.split("/").some((part) => part === ".." || part === "")) {
			errors.push(`unsafe ASCII relative path: ${name}`);
		}
		if (name.startsWith("__MACOSX/") || name.endsWith(".DS_Store") || /(^|\/)(?:readme|credits|license|self-check|diag)(?:\.|\/|$)/i.test(name)) {
			errors.push(`non-web document or packaging debris: ${name}`);
		}
		if (file.bytes.length > MAX_FILE_BYTES) errors.push(`${name} exceeds 10 MiB (${file.bytes.length} bytes)`);
		total += file.bytes.length;
	}
	if (total > MAX_TOTAL_BYTES) errors.push(`unpacked size ${total} exceeds 1 GiB`);
	return errors;
}

export function validateOfflineSource(files: PackageFile[]): string[] {
	const errors: string[] = [];
	for (const file of files) {
		if (!/\.(html|js|css|json)$/i.test(file.name)) continue;
		const source = new TextDecoder().decode(file.bytes);
		const rules: Array<[RegExp, string]> = [
			[/https?:\/\//i, "absolute HTTP(S) URL"],
			[/\b(?:fetch|XMLHttpRequest|WebSocket|EventSource|RTCPeerConnection|sendBeacon)\b/i, "network API"],
			[/\b(?:SharedWorker|Worker|Worklet|serviceWorker)\b/i, "worker or service-worker API"],
			[/\b(?:eval\s*\(|new\s+Function\s*\(|import\s*\()/, "dynamic code execution"],
			[/\b(?:window\.open|window\.close|requestFullscreen|history\.(?:pushState|replaceState)|popstate|beforeunload)\b/i, "unsupported navigation/fullscreen API"],
			[/<(?:iframe|object|embed)\b/i, "embedded browsing context"],
			[/<(?:input|textarea)\b|contenteditable|\bprompt\s*\(/i, "custom text/file input"],
			[/baiduboxapp|BoxJSBridge|WebViewJavascriptBridge|webkit\.messageHandlers|callNative|\b(?:wx|swan|tt|my|dd)\s*\./i, "host or other-platform bridge"],
		];
		for (const [pattern, label] of rules) if (pattern.test(source)) errors.push(`${file.name} contains ${label}`);
		if (/\b(?:navigator|document)\.(?:clipboard|geolocation|serviceWorker|share|vibrate)\b/i.test(source)) errors.push(`${file.name} uses restricted device API`);
		if (/\b(?:src|href)\s*=\s*["']\/\//i.test(source)) errors.push(`${file.name} contains a protocol-relative resource URL`);
	}
	return errors;
}

export function createDeflateZip(files: PackageFile[]): Uint8Array {
	const validation = validatePackageFiles(files);
	if (validation.length) throw new Error(validation.join("\n"));
	const local: Uint8Array[] = [];
	const central: Uint8Array[] = [];
	let localOffset = 0;
	for (const file of files) {
		const name = new TextEncoder().encode(file.name);
		const compressed = deflateRawSync(file.bytes, { level: 9 });
		const crc = crc32(file.bytes);
		const localHeader = concat([
			u32(0x04034b50), u16(20), u16(0x0800), u16(8), u16(0), u16(0x21),
			u32(crc), u32(compressed.length), u32(file.bytes.length), u16(name.length), u16(0), name,
		]);
		local.push(localHeader, compressed);
		central.push(concat([
			u32(0x02014b50), u16(0x0314), u16(20), u16(0x0800), u16(8), u16(0), u16(0x21),
			u32(crc), u32(compressed.length), u32(file.bytes.length), u16(name.length), u16(0), u16(0),
			u16(0), u16(0), u32((0o100644 << 16) >>> 0), u32(localOffset), name,
		]));
		localOffset += localHeader.length + compressed.length;
	}
	const directory = concat(central);
	const end = concat([
		u32(0x06054b50), u16(0), u16(0), u16(files.length), u16(files.length),
		u32(directory.length), u32(localOffset), u16(0),
	]);
	return concat([...local, directory, end]);
}
