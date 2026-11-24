#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate original, sample-free CC0 / CC BY 4.0 music for Watch of Yongchang.

Default: synthesize the distinct 72-second about-page cue and encode it as Ogg.
``--legacy`` reproduces the original menu cue and event SFX under assets/audio/.
``--output PATH`` selects another Ogg destination (useful for verification).

The musical material is deterministic additive synthesis: no recordings, samples,
models, or third-party compositions are used. Python's standard library and ffmpeg
are the only requirements. To the extent any rights remain, xingwangzhe dedicates
the generated audio under CC0 1.0 and additionally offers CC BY 4.0 at the
recipient's option. The prior CC0 dedication remains irrevocable.
https://creativecommons.org/publicdomain/zero/1.0/
https://creativecommons.org/licenses/by/4.0/
"""

from __future__ import annotations

import argparse
import array
import math
import random
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RUNTIME_OUT = ROOT / "game" / "assets" / "audio"
TAU = 2.0 * math.pi

# Original menu cue: C-gong pentatonic, retained as reproducible provenance for
# assets/audio/bgm_watch.ogg. The shipped source Ogg is not overwritten by default.
PENTA = [261.63, 293.66, 329.63, 392.00, 440.00]
SCALE = PENTA + [f * 2 for f in PENTA] + [f * 4 for f in PENTA]


def env(i: int, total: int, attack: float = 0.02, release: float = 0.3) -> float:
    t = i / SR
    dur = total / SR
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def tone(
    freq: float,
    dur: float,
    harmonics: tuple[float, ...] = (1.0, 0.32, 0.15, 0.07),
    vibrato: float = 0.0,
) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1 + vibrato * math.sin(TAU * 5.5 * t)) if vibrato else freq
        value = sum(
            amp * math.sin(TAU * f * k * t + k * 0.3)
            for k, amp in enumerate(harmonics, 1)
        )
        out.append(
            value
            * env(i, n, attack=min(0.03, dur * 0.1), release=min(0.35, dur * 0.4))
        )
    return out


def noise(dur: float, decay: float) -> list[float]:
    rng = random.Random(20261122)
    n = int(SR * dur)
    return [rng.uniform(-1, 1) * math.exp(-(i / SR) / decay) for i in range(n)]


def mix(*tracks: list[float], gain: float = 1.0) -> list[float]:
    length = max(len(track) for track in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, value in enumerate(track):
            out[i] += value
    peak = max(1e-6, max(abs(value) for value in out))
    return [value / peak * 0.82 * gain for value in out]


def write_mono_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767))
        for value in samples
    )
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(frames)
    print(f"{path.name}: {len(samples) / SR:.2f}s mono")


def legacy_menu() -> None:
    """Reproduce the original 32-beat menu loop from the initial CC0 commit."""
    bpm = 84
    beat = 60 / bpm
    melody = [
        0, 2, 4, 5, 4, 2, 1, 0, 2, 4, 7, 5, 4, 2, 1, 0,
        5, 4, 2, 1, 0, 2, 4, 5, 7, 5, 4, 2, 1, 2, 0, 0,
    ]
    bass = [0, 0, 3, 3, 5, 5, 0, 0] * 4
    total = int(SR * 32 * beat)
    tracks = []
    for index, note in enumerate(melody):
        segment = [0.0] * int(SR * index * beat)
        segment += tone(
            SCALE[note], beat * 0.92,
            harmonics=(1.0, 0.42, 0.18, 0.09), vibrato=0.004,
        )
        tracks.append(segment + [0.0] * max(0, total - len(segment)))
    for index, note in enumerate(bass):
        segment = [0.0] * int(SR * index * 2 * beat)
        segment += tone(SCALE[note] / 2, beat * 1.8, harmonics=(1.0, 0.25, 0.08))
        tracks.append(segment + [0.0] * max(0, total - len(segment)))
    for index in range(8):
        segment = [0.0] * int(SR * index * 4 * beat)
        segment += [value * 0.28 for value in noise(0.14, 0.035)]
        tracks.append(segment + [0.0] * max(0, total - len(segment)))
    write_mono_wav(OUT / "bgm_watch.wav", mix(*tracks, gain=0.55))


def legacy_sfx() -> None:
    write_mono_wav(OUT / "sfx_spawn.wav", tone(392.0, 0.16, vibrato=0.01) + [0.0] * 200)
    write_mono_wav(OUT / "sfx_build.wav", mix(tone(261.63, 0.22), tone(392.0, 0.18), gain=0.7))
    write_mono_wav(OUT / "sfx_fire.wav", [value * 0.5 for value in noise(0.1, 0.025)])
    write_mono_wav(
        OUT / "sfx_hit.wav",
        [value * 0.35 for value in noise(0.07, 0.015)] + tone(180.0, 0.06),
    )
    write_mono_wav(
        OUT / "sfx_merge.wav",
        mix(tone(523.25, 0.18), tone(659.25, 0.24), tone(783.99, 0.3), gain=0.7),
    )
    write_mono_wav(OUT / "sfx_wave.wav", mix(tone(196.0, 0.35), tone(293.66, 0.4), gain=0.8))
    write_mono_wav(OUT / "sfx_alarm.wav", mix(tone(220.0, 0.2), tone(220.0, 0.2), gain=0.75))
    write_mono_wav(
        OUT / "sfx_win.wav",
        mix(tone(523.25, 0.5), tone(659.25, 0.45), tone(783.99, 0.5), tone(1046.5, 0.7), gain=0.8),
    )
    write_mono_wav(
        OUT / "sfx_lose.wav",
        mix(tone(392.0, 0.4), tone(329.63, 0.45), tone(261.63, 0.6), gain=0.8),
    )


def _fade_window(t: float, duration: float, attack: float, release: float) -> float:
    if t < attack:
        return 0.5 - 0.5 * math.cos(math.pi * t / attack)
    if t > duration - release:
        return 0.5 - 0.5 * math.cos(math.pi * (duration - t) / release)
    return 1.0


def _add_voice(
    samples: array.array,
    start: float,
    duration: float,
    frequency: float,
    amplitude: float,
    pan: float,
    kind: str,
    phase: float = 0.0,
) -> None:
    """Add one deterministic synthesized voice with equal-power stereo panning."""
    first = int(start * SR)
    count = min(int(duration * SR), len(samples) // 2 - first)
    left = math.sqrt((1.0 - pan) * 0.5)
    right = math.sqrt((1.0 + pan) * 0.5)
    for i in range(count):
        t = i / SR
        if kind == "pad":
            window = _fade_window(t, duration, 1.1, 1.4)
            movement = 0.88 + 0.12 * math.sin(TAU * 0.11 * t + phase)
            value = (
                math.sin(TAU * frequency * t + phase)
                + 0.24 * math.sin(TAU * frequency * 2.0 * t + phase * 0.7)
                + 0.08 * math.sin(TAU * frequency * 3.0 * t)
            ) * window * movement
        elif kind == "bell":
            window = _fade_window(t, duration, 0.012, 0.45)
            value = (
                math.sin(TAU * frequency * t + phase)
                + 0.34 * math.sin(TAU * frequency * 2.01 * t)
                + 0.13 * math.sin(TAU * frequency * 3.97 * t)
            ) * math.exp(-t / 1.45) * window
        elif kind == "pluck":
            window = _fade_window(t, duration, 0.006, 0.25)
            value = (
                math.sin(TAU * frequency * t + phase)
                + 0.28 * math.sin(TAU * frequency * 2.0 * t)
                + 0.11 * math.sin(TAU * frequency * 4.0 * t)
            ) * math.exp(-t / 0.52) * window
        else:  # low root
            window = _fade_window(t, duration, 0.3, 1.0)
            value = (
                math.sin(TAU * frequency * t + phase)
                + 0.12 * math.sin(TAU * frequency * 2.0 * t)
            ) * math.exp(-t / 3.0) * window
        frame = first + i
        samples[frame * 2] += value * amplitude * left
        samples[frame * 2 + 1] += value * amplitude * right


def about_music() -> tuple[Path, float]:
    """Compose a slow 72-second D-minor/pentatonic credits cue, distinct from menu BGM."""
    duration = 72.0
    samples = array.array("f", [0.0]) * (int(duration * SR) * 2)
    chords = [
        (146.832, 220.000, 293.665, 349.228),  # Dm(add9) colour
        (130.813, 195.998, 261.626, 329.628),  # C(add9)
        (116.541, 174.614, 233.082, 293.665),  # Bb(add9)
        (110.000, 164.814, 220.000, 261.626),  # Am(add9)
    ]
    melodies = [
        (293.665, 349.228, 440.000, 523.251),
        (261.626, 329.628, 391.995, 440.000),
        (233.082, 293.665, 349.228, 466.164),
        (220.000, 261.626, 329.628, 391.995),
    ]
    for phrase in range(12):
        start = phrase * 6.0
        chord = chords[phrase % len(chords)]
        for voice, frequency in enumerate(chord):
            _add_voice(
                samples, start, 5.92, frequency, 0.030,
                (-0.62, 0.48, -0.20, 0.66)[voice], "pad", phase=voice * 0.71,
            )
        _add_voice(samples, start, 5.8, chord[0] / 2.0, 0.065, 0.0, "root")
        melody = melodies[phrase % len(melodies)]
        pattern = (0, 2, 1, 3, 2, 1, 0, 2)
        for step, note_index in enumerate(pattern):
            note_start = start + step * 0.75
            pan = -0.38 if step % 2 == 0 else 0.38
            _add_voice(
                samples, note_start, min(3.8, duration - note_start),
                melody[note_index], 0.040 if step % 2 == 0 else 0.026,
                pan, "pluck", phase=step * 0.23,
            )
        for bell_index, (offset, note_index) in enumerate(((0.5, 1), (3.0, 2), (5.0, 0))):
            note_start = start + offset
            _add_voice(
                samples, note_start, min(5.0, duration - note_start),
                melody[note_index] * (2.0 if phrase % 3 == 0 else 1.0),
                0.035 if bell_index == 0 else 0.026,
                (-0.55, 0.52, 0.18)[bell_index], "bell", phase=phrase * 0.17,
            )

    peak = max(1e-9, max(abs(value) for value in samples))
    gain = 0.84 / peak
    frames = array.array("h")
    for frame in range(len(samples) // 2):
        t = frame / SR
        loop_fade = _fade_window(t, duration, 0.45, 0.45)
        left = int(max(-1.0, min(1.0, samples[frame * 2] * gain * loop_fade)) * 32767)
        right = int(max(-1.0, min(1.0, samples[frame * 2 + 1] * gain * loop_fade)) * 32767)
        frames.append(left)
        frames.append(right)

    handle = tempfile.NamedTemporaryFile(prefix="watch-about-", suffix=".wav", delete=False)
    wav_path = Path(handle.name)
    handle.close()
    try:
        with wave.open(str(wav_path), "wb") as wav:
            wav.setnchannels(2)
            wav.setsampwidth(2)
            wav.setframerate(SR)
            wav.writeframes(frames.tobytes())
        return wav_path, duration
    except Exception:
        wav_path.unlink(missing_ok=True)
        raise


def encode_ogg(wav_path: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4",
            "-ar", str(SR), str(output),
        ],
        check=True,
    )
    print(f"{output}: original CC0 about-page music")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--legacy", action="store_true", help="write original menu/SFX WAVs under assets/audio")
    parser.add_argument("--output", type=Path, help="about-page Ogg destination")
    args = parser.parse_args()
    if args.legacy:
        legacy_menu()
        legacy_sfx()
        return
    wav_path, duration = about_music()
    try:
        encode_ogg(wav_path, args.output or RUNTIME_OUT / "bgm_about.ogg")
    finally:
        wav_path.unlink(missing_ok=True)
    print(f"about cue duration: {duration:.2f}s; no third-party samples")


if __name__ == "__main__":
    main()
