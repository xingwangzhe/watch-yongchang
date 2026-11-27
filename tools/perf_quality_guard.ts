const [stressPath, flowPath] = Bun.argv.slice(2);
if (!stressPath || !flowPath) {
	throw new Error("Usage: bun run tools/perf_quality_guard.ts <stress-log> <flow-log>");
}

const stress = await Bun.file(stressPath).text();
const flow = await Bun.file(flowPath).text();
const samples = [...stress.matchAll(/\[stress\] wall_fps=([\d.]+) wall_frame_ms=([\d.]+) logic_ms=([\d.]+) engine_fps=([\d.]+) enemies=(\d+)/g)];
if (samples.length === 0) throw new Error("No 460-enemy stress measurements were recorded.");
const latest = samples[samples.length - 1];
const logicMs = Number(latest[3]);
const enemies = Number(latest[5]);
if (enemies !== 460) throw new Error(`Capacity sample used ${enemies} enemies; expected 460.`);
if (!Number.isFinite(logicMs) || logicMs > 16.67) throw new Error(`460-enemy update latency ${logicMs} ms exceeds the 16.67 ms frame budget.`);

const flowRows = [...flow.matchAll(/\[flow-async\] (tideland|watergate|crossstreet).*?p95_ms=([\d.]+)/g)];
const maps = new Map(flowRows.map(([, id, p95]) => [id, Number(p95)]));
for (const id of ["tideland", "watergate", "crossstreet"]) {
	const p95 = maps.get(id);
	if (p95 === undefined) throw new Error(`No flow-field latency sample for ${id}.`);
	if (!Number.isFinite(p95) || p95 > 1.0) throw new Error(`${id} flow-field p95 ${p95} ms exceeds the 1.0 ms per-slice budget.`);
}
console.log(`Quality/latency/capacity guard passed: 460 enemies at ${logicMs.toFixed(3)} ms/update; flow-field p95 below 1.0 ms on all 3 maps.`);
