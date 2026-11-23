import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const ROOT = resolve(import.meta.dir, "..");
const RENDERER = resolve(
  ROOT,
  "third_party/moss-tts-nano/rust/target/release/examples/render",
);
const VOICE_JSON = resolve(ROOT, "game/data/voice_lines.json");
const NARRATIVE_JSON = resolve(ROOT, "game/data/narrative.json");
const OUTPUT_DIR = resolve(ROOT, "game/assets/audio/voice");
const SAMPLE_RATE = 48_000;
const CHANNELS = 2;

type NarrativeLine = {
  id: string;
  zh: string;
  en: string;
};

type VoiceData = {
  lines: Record<string, { voice: string }>;
};

function loadLines(): Map<string, NarrativeLine> {
  const narrative = JSON.parse(
    require("node:fs").readFileSync(NARRATIVE_JSON, "utf8"),
  ) as Record<string, NarrativeLine[]>;
  const rows = new Map<string, NarrativeLine>();
  for (const section of ["prologue", "main_intro", "epilogue"]) {
    for (const line of narrative[section] ?? []) {
      rows.set(line.id, line);
    }
  }
  return rows;
}

function writeWav(path: string, raw: Buffer): void {
  const samples = new Float32Array(
    raw.buffer,
    raw.byteOffset,
    raw.byteLength / Float32Array.BYTES_PER_ELEMENT,
  );
  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const gain = peak > 0.0001 ? 0.7 / peak : 1;
  const lead = Math.round(0.12 * SAMPLE_RATE);
  const tail = Math.round(0.24 * SAMPLE_RATE);
  const fade = Math.round(0.025 * SAMPLE_RATE);
  const totalFrames = samples.length / CHANNELS + lead + tail;
  const out = Buffer.alloc(44 + totalFrames * CHANNELS * 4);

  out.write("RIFF", 0);
  out.writeUInt32LE(out.length - 8, 4);
  out.write("WAVE", 8);
  out.write("fmt ", 12);
  out.writeUInt32LE(16, 16);
  out.writeUInt16LE(3, 20);
  out.writeUInt16LE(CHANNELS, 22);
  out.writeUInt32LE(SAMPLE_RATE, 24);
  out.writeUInt32LE(SAMPLE_RATE * CHANNELS * 4, 28);
  out.writeUInt16LE(CHANNELS * 4, 32);
  out.writeUInt16LE(32, 34);
  out.write("data", 36);
  out.writeUInt32LE(totalFrames * CHANNELS * 4, 40);

  let offset = 44 + lead * CHANNELS * 4;
  for (let frame = 0; frame < samples.length / CHANNELS; frame++) {
    const edge = Math.min(frame, samples.length / CHANNELS - 1 - frame);
    const envelope = edge < fade ? edge / fade : 1;
    for (let channel = 0; channel < CHANNELS; channel++) {
      const value = samples[frame * CHANNELS + channel] * gain * envelope;
      out.writeFloatLE(value, offset);
      offset += 4;
    }
  }
  mkdirSync(dirname(path), { recursive: true });
  require("node:fs").writeFileSync(path, out);
}

type Clause = { text: string; end: string };

function splitClauses(text: string, language: "zh" | "en"): Clause[] {
  const pattern =
    language === "zh" ? /[^，。；！？：]+[，。；！？：]?/g : /[^,.;!?]+[,.;!?]?/g;
  return (text.match(pattern) ?? [text])
    .map((clause) => clause.trim())
    .filter((clause) => clause.length > 0)
    .map((clause) => ({
      text: clause.replace(/[，。；！？：,.;!?]+$/u, "").trim(),
      end: clause.at(-1) ?? "",
    }))
    .filter((clause) => clause.text.length > 0);
}

function pauseSamples(clause: Clause, language: "zh" | "en"): number {
  const terminal = clause.end;
  const sentenceEnd = language === "zh" ? "。！？" : ".!?";
  const softEnd = language === "zh" ? "；" : ";";
  if (sentenceEnd.includes(terminal)) return Math.round(0.55 * SAMPLE_RATE);
  if (softEnd.includes(terminal)) return Math.round(0.4 * SAMPLE_RATE);
  return Math.round(0.28 * SAMPLE_RATE);
}

function compressSilence(raw: Buffer): Float32Array {
  const samples = new Float32Array(
    raw.buffer,
    raw.byteOffset,
    raw.byteLength / Float32Array.BYTES_PER_ELEMENT,
  );
  const frameSize = Math.round(0.01 * SAMPLE_RATE);
  const minSilenceFrames = 10;
  const keepFrames = 3;
  const threshold = 0.006;
  const frames = Math.floor(samples.length / CHANNELS / frameSize);
  const active: boolean[] = [];
  for (let frame = 0; frame < frames; frame++) {
    let energy = 0;
    for (let i = 0; i < frameSize; i++) {
      const index = (frame * frameSize + i) * CHANNELS;
      energy += samples[index] * samples[index] + samples[index + 1] * samples[index + 1];
    }
    active.push(Math.sqrt(energy / (frameSize * CHANNELS)) > threshold);
  }
  const keep: boolean[] = new Array(frames).fill(true);
  let index = 0;
  while (index < frames) {
    if (active[index]) {
      index++;
      continue;
    }
    let end = index;
    while (end < frames && !active[end]) end++;
    if (end - index >= minSilenceFrames) {
      for (let i = index + keepFrames; i < end; i++) keep[i] = false;
    }
    index = end;
  }
  const keptFrames = keep.filter(Boolean).length;
  const out = new Float32Array(keptFrames * frameSize * CHANNELS);
  let cursor = 0;
  for (let frame = 0; frame < frames; frame++) {
    if (!keep[frame]) continue;
    const start = frame * frameSize * CHANNELS;
    out.set(samples.subarray(start, start + frameSize * CHANNELS), cursor);
    cursor += frameSize * CHANNELS;
  }
  return out;
}

function concatClauses(buffers: Buffer[], clauses: Clause[], language: "zh" | "en"): Buffer {
  const compressed = buffers.map(compressSilence);
  let sampleCount = 0;
  for (const samples of compressed) sampleCount += samples.length;
  for (const clause of clauses) sampleCount += pauseSamples(clause, language) * CHANNELS;
  const merged = new Float32Array(sampleCount);
  let cursor = 0;
  for (let index = 0; index < compressed.length; index++) {
    merged.set(compressed[index], cursor);
    cursor += compressed[index].length;
    cursor += pauseSamples(clauses[index], language) * CHANNELS;
  }
  return Buffer.from(merged.buffer);
}

const voiceData = JSON.parse(
  require("node:fs").readFileSync(VOICE_JSON, "utf8"),
) as VoiceData;
const lines = loadLines();
mkdirSync(OUTPUT_DIR, { recursive: true });

for (const [id, entry] of Object.entries(voiceData.lines)) {
  const line = lines.get(id);
  if (!line) {
    console.warn(`skip ${id}: narrative line not found`);
    continue;
  }
  for (const [language, text] of [
    ["zh", line.zh],
    ["en", line.en],
  ] as const) {
    const suffix = language === "zh" ? "" : "_en";
    const wavPath = resolve(OUTPUT_DIR, `${id}${suffix}.wav`);
    console.log(`render ${id}${suffix} (${entry.voice})`);
    const clauses = splitClauses(text, language);
    const buffers: Buffer[] = [];
    for (let index = 0; index < clauses.length; index++) {
      const rawPath = resolve(OUTPUT_DIR, `${id}${suffix}_${index}.f32`);
      const result = spawnSync(
        RENDERER,
        [
          "--text",
          clauses[index].text,
          "--voice",
          entry.voice,
          "--output",
          rawPath,
        ],
        {
          cwd: resolve(ROOT, "third_party/moss-tts-nano/rust"),
          stdio: "inherit",
        },
      );
      if (result.status !== 0) process.exit(result.status ?? 1);
      buffers.push(require("node:fs").readFileSync(rawPath));
      require("node:fs").unlinkSync(rawPath);
    }
    writeWav(wavPath, concatClauses(buffers, clauses, language));
  }
}
