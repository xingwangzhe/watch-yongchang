#!/usr/bin/env python3
"""第三方音频素材转换流水线。

将 generated/audio_thirdparty/raw/ 下的 CC0 / CC-BY 原始素材转换为
game/assets/audio/ 成品（文件名与旧合成版一致，AudioManager 零改动）。

- 短音效：响度归一化（loudnorm I=-16 TP=-1.5），统一输出 Ogg Vorbis q=4。
- BGM：仅重编码，不做响度处理（保持原动态）。
- sfx_alarm 原始 7s 过长，截短至 2.2s 并加 0.4s 淡出。

用法：python3 tools/process_thirdparty_audio.py
依赖：ffmpeg
"""

import subprocess
import sys
from pathlib import Path

PROJ = Path(__file__).resolve().parent.parent
RAW = PROJ / "generated" / "audio_thirdparty" / "raw"
OUT = PROJ / "game" / "assets" / "audio"

# 成品文件名 -> (原始文件, 是否响度归一化, 截短秒数(0=不截))
JOBS = {
    "bgm_watch.ogg": ("samurai-nights-demo_majadroid_CC-BY.mp3", False, 0.0),
    "sfx_fire.ogg": ("bow_ogrebane_CC0.wav", True, 0.0),
    "sfx_hit.ogg": ("melee-sound_remaxim_CC0.wav", True, 0.0),
    "sfx_build.ogg": ("chop_kenney_CC0.ogg", True, 0.0),
    "sfx_spawn.ogg": ("sword-unsheathe_artisticdude_CC0.wav", True, 0.0),
    "sfx_wave.ogg": ("rise01_wobbleboxx_CC0.aif", True, 0.0),
    "sfx_alarm.ogg": ("alarm_wobbleboxx_CC0.aif", True, 2.2),
    "sfx_merge.ogg": ("metal-ringing_artisticdude_CC0.wav", True, 0.0),
    "sfx_win.ogg": ("upper01_wobbleboxx_CC0.aif", True, 0.0),
    "sfx_lose.ogg": ("downer01_wobbleboxx_CC0.aif", True, 0.0),
}


def convert(target: str, source: str, normalize: bool, trim: float) -> None:
    src = RAW / source
    dst = OUT / target
    if not src.exists():
        print(f"[SKIP] {source} 不存在")
        return
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src)]
    if trim > 0:
        cmd += ["-t", str(trim)]
    filters = []
    if normalize:
        filters.append("loudnorm=I=-16:TP=-1.5:LRA=11")
    if trim > 0:
        filters.append("afade=t=out:st=%.2f:d=0.4" % max(0.0, trim - 0.4))
    if filters:
        cmd += ["-af", ",".join(filters)]
    cmd += ["-c:a", "libvorbis", "-q:a", "4", str(dst)]
    subprocess.run(cmd, check=True)
    print(f"[OK] {source} -> {target}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for target, (source, normalize, trim) in JOBS.items():
        convert(target, source, normalize, trim)
    print("[DONE] 10 个成品音频已输出至", OUT)


if __name__ == "__main__":
    sys.exit(main())
