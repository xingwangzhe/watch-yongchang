#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import signal
import socket
import stat
import struct
import subprocess
import time
import traceback
import urllib.request
import zipfile
import zlib

DORA_VERSION = "1.10.2"
APPIMAGE_SHA256 = "6726c68b3714c5ee937d0e5573f21895ef9eddd278fada65761a0e253e650725"
SHADER_URL = "https://raw.githubusercontent.com/IppClub/Dora-SSR/v1.10.2/Source/3rdParty/bgfx/src/bgfx_shader.sh"
SHADER_SHA256 = "93441aea21714b45d370768261783dbdb908f6eb713edee8b3daf96d4ec53024"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def port_open(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.25):
            return True
    except OSError:
        return False


def terminate(process: subprocess.Popen | None) -> None:
    if process is None or process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            pass


def safe_extract(archive_path: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"source ZIP CRC failure: {bad}")
        for info in archive.infolist():
            path = PurePosixPath(info.filename)
            mode = info.external_attr >> 16
            if path.is_absolute() or ".." in path.parts or "\\" in info.filename or stat.S_ISLNK(mode):
                raise RuntimeError(f"unsafe source ZIP entry: {info.filename}")
        archive.extractall(destination)


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_distance:
        return left
    if above_distance <= upper_distance:
        return above
    return upper_left


def png_metrics(path: Path) -> dict:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    offset = 8
    width = height = bit_depth = color_type = interlace = 0
    compressed = []
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.append(payload)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise ValueError(f"unsupported PNG format: depth={bit_depth}, color={color_type}, interlace={interlace}")
    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(b"".join(compressed))
    if len(raw) != height * (stride + 1):
        raise ValueError("unexpected PNG scanline length")
    previous = bytearray(stride)
    luminances: list[int] = []
    colors: set[tuple[int, int, int]] = set()
    cursor = 0
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor : cursor + stride])
        cursor += stride
        for index in range(stride):
            left = row[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                row[index] = (row[index] + left) & 0xFF
            elif filter_type == 2:
                row[index] = (row[index] + above) & 0xFF
            elif filter_type == 3:
                row[index] = (row[index] + ((left + above) // 2)) & 0xFF
            elif filter_type == 4:
                row[index] = (row[index] + paeth(left, above, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter: {filter_type}")
        for x in range(0, width, 8):
            index = x * channels
            red, green, blue = row[index : index + 3]
            luminances.append((red * 299 + green * 587 + blue * 114) // 1000)
            colors.add((red, green, blue))
        previous = row
    mean = sum(luminances) / len(luminances)
    variance = sum((value - mean) ** 2 for value in luminances) / len(luminances)
    return {
        "width": width,
        "height": height,
        "luminance_mean": round(mean, 3),
        "luminance_variance": round(variance, 3),
        "sampled_unique_colors": len(colors),
        "rendered": variance > 100.0 and len(colors) > 16,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--appimage", required=True, type=Path)
    parser.add_argument("--project-zip", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    appimage = args.appimage.resolve()
    project_zip = args.project_zip.resolve()
    work = args.work.resolve()
    output = args.output.resolve()
    work.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    result: dict = {"dora_version": DORA_VERSION, "passed": False, "finished": False}

    def save() -> None:
        temporary = output / "preview-result.json.tmp"
        temporary.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        os.replace(temporary, output / "preview-result.json")

    xvfb_process = None
    app_process = None
    xvfb_log = None
    app_log = None
    try:
        if port_open(8866):
            raise RuntimeError("port 8866 is already occupied; refusing to reuse an unknown Dora service")
        actual_appimage_hash = sha256(appimage)
        if actual_appimage_hash != APPIMAGE_SHA256:
            raise RuntimeError(f"Dora AppImage SHA-256 mismatch: {actual_appimage_hash}")
        appimage.chmod(appimage.stat().st_mode | stat.S_IXUSR)
        extracted = work / "squashfs-root"
        if extracted.exists():
            raise RuntimeError(f"extraction directory already exists: {extracted}")
        extraction = subprocess.run(
            [appimage, "--appimage-extract"],
            cwd=work,
            capture_output=True,
            text=True,
            timeout=180,
        )
        (output / "appimage-extract.log").write_text(extraction.stdout + extraction.stderr, encoding="utf-8")
        if extraction.returncode != 0 or not (extracted / "AppRun").is_file():
            raise RuntimeError("Dora AppImage extraction failed")
        root = extracted
        header = root / "usr/share/dora-ssr/Assets/bgfx_shader.sh"
        header_existed = header.is_file()
        if not header_existed:
            with urllib.request.urlopen(SHADER_URL, timeout=60) as response:
                content = response.read()
            if hashlib.sha256(content).hexdigest() != SHADER_SHA256:
                raise RuntimeError("official Dora shader header SHA-256 mismatch")
            header.write_bytes(content)
        if sha256(header) != SHADER_SHA256:
            raise RuntimeError("Dora shader header content does not match official v1.10.2 source")
        result["package"] = {
            "appimage_sha256": actual_appimage_hash,
            "shader_header_present_in_appimage": header_existed,
            "official_shader_header_restored": not header_existed,
            "shader_header_sha256": sha256(header),
            "workaround_scope": "CI runtime only; the downloaded AppImage remains unchanged",
        }

        project = work / "project"
        safe_extract(project_zip, project)
        if not (project / "init.lua").is_file() or not (project / "watch-yongchang/project.godot").is_file():
            raise RuntimeError("Dora source ZIP layout is invalid")

        runtime_env = os.environ.copy()
        runtime_env.pop("LD_LIBRARY_PATH", None)
        runtime_home = work / "home"
        runtime_data = work / "data"
        runtime_config = work / "config"
        runtime_tmp = work / "tmp"
        for directory in (runtime_home, runtime_data, runtime_config, runtime_tmp):
            directory.mkdir(parents=True, exist_ok=True)
        runtime_env.update(
            {
                "HOME": str(runtime_home),
                "XDG_DATA_HOME": str(runtime_data),
                "XDG_CONFIG_HOME": str(runtime_config),
                "TMPDIR": str(runtime_tmp),
                "DISPLAY": ":99",
                "WAYLAND_DISPLAY": "",
                "EGL_PLATFORM": "x11",
                "LIBGL_ALWAYS_SOFTWARE": "1",
                "SDL_VIDEODRIVER": "x11",
                "GDK_BACKEND": "x11",
            }
        )
        xvfb_log = (output / "xvfb.log").open("w", encoding="utf-8")
        xvfb_process = subprocess.Popen(
            ["Xvfb", ":99", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"],
            env=runtime_env,
            stdout=xvfb_log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        socket_path = Path("/tmp/.X11-unix/X99")
        deadline = time.monotonic() + 20
        while not socket_path.exists() and time.monotonic() < deadline:
            if xvfb_process.poll() is not None:
                raise RuntimeError("Xvfb exited before readiness")
            time.sleep(0.1)
        if not socket_path.exists():
            raise RuntimeError("Xvfb socket did not appear")

        app_log = (output / "dora-runtime.log").open("w", encoding="utf-8")
        app_process = subprocess.Popen(
            [root / "AppRun"],
            cwd=work,
            env=runtime_env,
            stdout=app_log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        deadline = time.monotonic() + 60
        while not port_open(8866) and time.monotonic() < deadline:
            if app_process.poll() is not None:
                raise RuntimeError("Dora exited before service readiness")
            time.sleep(0.2)
        if not port_open(8866):
            raise RuntimeError("Dora service did not open port 8866")
        result["service_ready"] = True

        cli_env = runtime_env.copy()
        cli_env["LD_LIBRARY_PATH"] = str(root / "usr/lib")
        cli = [
            root / "usr/bin/dora-ssr",
            "--asset",
            root / "usr/share/dora-ssr/Assets",
            "cli",
        ]

        def command(arguments: list[str], timeout: int = 120) -> subprocess.CompletedProcess:
            return subprocess.run(
                cli + arguments,
                cwd=work,
                env=cli_env,
                capture_output=True,
                text=True,
                timeout=timeout,
            )

        stop_before = command(["stop"], timeout=30)
        preview = command(
            [
                "agent",
                "preview",
                "-p",
                str(project),
                "--entry",
                "init.lua",
                "--capture-at",
                "1,5,9",
                "--queue-timeout",
                "30",
                "--timeout",
                "120",
            ],
            timeout=150,
        )
        (output / "preview-command.json").write_text(
            json.dumps(
                {
                    "returncode": preview.returncode,
                    "stdout": preview.stdout,
                    "stderr": preview.stderr,
                    "stop_before": {"returncode": stop_before.returncode, "stdout": stop_before.stdout, "stderr": stop_before.stderr},
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        payload = json.loads(preview.stdout)
        result["preview"] = payload
        frames = payload.get("frames", [])
        frame_records = []
        for index, frame in enumerate(frames, start=1):
            frame_path = Path(frame["path"])
            source = project / frame_path
            if not source.is_file():
                matches = list(project.rglob(frame_path.name))
                if len(matches) != 1:
                    raise RuntimeError(f"preview frame not found uniquely: {frame_path}")
                source = matches[0]
            destination = output / f"frame-{index:02d}.png"
            shutil.copy2(source, destination)
            metrics = png_metrics(destination)
            metrics.update(
                {
                    "elapsed_seconds": frame.get("elapsedSeconds"),
                    "source": frame["path"],
                    "artifact": destination.name,
                    "sha256": sha256(destination),
                }
            )
            frame_records.append(metrics)
        result["frames"] = frame_records
        result["frame_count"] = len(frame_records)
        result["distinct_frame_hashes"] = len({frame["sha256"] for frame in frame_records})
        stop_after = command(["stop"], timeout=30)
        result["stop_after"] = {"returncode": stop_after.returncode, "stdout": stop_after.stdout, "stderr": stop_after.stderr}
        critical_errors = []
        for log_path in (output / "dora-runtime.log", output / "xvfb.log"):
            if log_path.is_file():
                for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
                    if any(token in line for token in ("SCRIPT ERROR:", "Cannot open include file", "Godot error:")):
                        critical_errors.append(f"{log_path.name}: {line}")
        result["critical_errors"] = critical_errors
        result["passed"] = (
            preview.returncode == 0
            and payload.get("success") is True
            and len(frame_records) == 3
            and all(frame["rendered"] for frame in frame_records)
            and all((frame["width"], frame["height"]) == (640, 480) for frame in frame_records)
            and stop_after.returncode == 0
            and not critical_errors
        )
        if not result["passed"]:
            raise RuntimeError("Dora preview acceptance failed")
    except Exception:
        result["error"] = traceback.format_exc()
    finally:
        try:
            if port_open(8866):
                cleanup_env = os.environ.copy()
                cleanup_env["LD_LIBRARY_PATH"] = str(work / "squashfs-root/usr/lib")
                subprocess.run(
                    [work / "squashfs-root/usr/bin/dora-ssr", "--asset", work / "squashfs-root/usr/share/dora-ssr/Assets", "cli", "stop"],
                    env=cleanup_env,
                    capture_output=True,
                    text=True,
                    timeout=20,
                    check=False,
                )
        except Exception:
            result["cleanup_cli_error"] = traceback.format_exc()
        terminate(app_process)
        terminate(xvfb_process)
        if app_log:
            app_log.close()
        if xvfb_log:
            xvfb_log.close()
        deadline = time.monotonic() + 10
        while port_open(8866) and time.monotonic() < deadline:
            time.sleep(0.1)
        result["port_8866_open_after"] = port_open(8866)
        result["processes_cleaned"] = app_process is not None and xvfb_process is not None and app_process.poll() is not None and xvfb_process.poll() is not None and not result["port_8866_open_after"]
        if not result["processes_cleaned"]:
            result["passed"] = False
        result["finished"] = True
        save()
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
