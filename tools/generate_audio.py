#!/usr/bin/env python3
"""程序化生成《守望·永昌》原创 CC0 音频：五声音阶 BGM + 事件音效。
无第三方采样、无版权风险，输出 44.1kHz 16bit WAV，可由 ffmpeg 转 OGG。
用法: venv/bin/python tools/generate_audio.py
"""
import math
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)

# 五声音阶（宫商角徵羽）频率，C4 起
PENTA = [261.63, 293.66, 329.63, 392.00, 440.00]
SCALE = PENTA + [f * 2 for f in PENTA] + [f * 4 for f in PENTA]


def env(i: int, total: int, attack=0.02, release=0.3) -> float:
    t = i / SR
    dur = total / SR
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def tone(freq: float, dur: float, harmonics=(1.0, 0.32, 0.15, 0.07), vibrato=0.0) -> list[float]:
    """加法合成：基频 + 泛音，可加颤音，返回 float 采样。"""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t)) if vibrato else freq
        s = 0.0
        for k, amp in enumerate(harmonics, 1):
            s += amp * math.sin(2 * math.pi * f * k * t + k * 0.3)
        out.append(s * env(i, n, attack=min(0.03, dur * 0.1), release=min(0.35, dur * 0.4)))
    return out


def noise(dur: float, decay: float) -> list[float]:
    import random
    random.seed(20261122)
    n = int(SR * dur)
    return [random.uniform(-1, 1) * math.exp(-t / decay) for t in (i / SR for i in range(n))]


def mix(*tracks, gain=1.0) -> list[float]:
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for tr in tracks:
        for i, v in enumerate(tr):
            out[i] += v
    peak = max(1e-6, max(abs(v) for v in out))
    return [v / peak * 0.82 * gain for v in out]


def write_wav(name: str, samples: list[float]) -> None:
    p = OUT / name
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in samples))
    print(f"{p.name}: {len(samples)/SR:.2f}s")


def bgm() -> None:
    """32 拍循环：宫调式五声，古筝式拨弦 + 笛声长音 + 鼓点。"""
    bpm = 84
    beat = 60 / bpm
    melody = [0, 2, 4, 5, 4, 2, 1, 0, 2, 4, 7, 5, 4, 2, 1, 0,
              5, 4, 2, 1, 0, 2, 4, 5, 7, 5, 4, 2, 1, 2, 0, 0]
    bass = [0, 0, 3, 3, 5, 5, 0, 0] * 4
    tracks = []
    # 旋律：每拍一个音，古筝泛音
    for idx, note in enumerate(melody):
        seg = [0.0] * int(SR * idx * beat)
        seg += tone(SCALE[note], beat * 0.92, harmonics=(1.0, 0.42, 0.18, 0.09), vibrato=0.004)
        tracks.append(seg + [0.0] * max(0, int(SR * 32 * beat) - len(seg)))
    # 低音：每两拍
    for idx, note in enumerate(bass):
        seg = [0.0] * int(SR * idx * 2 * beat)
        seg += tone(SCALE[note] / 2, beat * 1.8, harmonics=(1.0, 0.25, 0.08))
        tracks.append(seg + [0.0] * max(0, int(SR * 32 * beat) - len(seg)))
    # 鼓点：每四拍一次轻击
    for idx in range(8):
        seg = [0.0] * int(SR * idx * 4 * beat)
        seg += [v * 0.28 for v in noise(0.14, 0.035)]
        tracks.append(seg + [0.0] * max(0, int(SR * 32 * beat) - len(seg)))
    write_wav("bgm_watch.mp3.wav", mix(*tracks, gain=0.55))


def sfx() -> None:
    write_wav("sfx_spawn.wav", tone(392.0, 0.16, vibrato=0.01) + [0.0] * 200)
    write_wav("sfx_build.wav", mix(tone(261.63, 0.22), tone(392.0, 0.18), gain=0.7))
    write_wav("sfx_fire.wav", [v * 0.5 for v in noise(0.1, 0.025)])
    write_wav("sfx_hit.wav", [v * 0.35 for v in noise(0.07, 0.015)] + tone(180.0, 0.06))
    write_wav("sfx_merge.wav", mix(tone(523.25, 0.18), tone(659.25, 0.24), tone(783.99, 0.3), gain=0.7))
    write_wav("sfx_wave.wav", mix(tone(196.0, 0.35), tone(293.66, 0.4), gain=0.8))
    write_wav("sfx_alarm.wav", mix(tone(220.0, 0.2), tone(220.0, 0.2), gain=0.75))
    win = mix(tone(523.25, 0.5), tone(659.25, 0.45), tone(783.99, 0.5), tone(1046.5, 0.7), gain=0.8)
    write_wav("sfx_win.wav", win)
    lose = mix(tone(392.0, 0.4), tone(329.63, 0.45), tone(261.63, 0.6), gain=0.8)
    write_wav("sfx_lose.wav", lose)


if __name__ == "__main__":
    bgm()
    sfx()
    print("done")
