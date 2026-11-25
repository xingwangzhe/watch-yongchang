#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import stat
import struct
import subprocess
import sys
import time
import zipfile
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
ZIP_STAMP = (1980, 1, 1, 0, 0, 0)
REQUIRED_PCK = {
    "LICENSE",
    "NOTICE",
    "LICENSE-CC-BY-4.0.txt",
    "assets/audio/LICENSES.md",
    "assets/fonts/OFL.txt",
    "assets/icons/game_icons/ATTRIBUTION.md",
    "assets/fx/jeff_fx/LICENSE.txt",
}
FORBIDDEN_PARTS = (
    "addons/gut/",
    "addons/gda_harness/",
    ".godot/editor/",
    ".godot/shader_cache/",
)
FORBIDDEN_SOURCE_PARTS = (
    ".godot/",
    ".workbuddy/",
    ".codex/",
    ".claude/",
    "docs/01-参考资料包/",
    "docs/02-主题资料/",
    "docs/03-站点图片/",
    "docs/04-结构化数据/",
    "docs/05-页面原文/",
    "docs/source-manifest.json",
    "docs/06-资料文本化/",
    "third_party/",
)
LEGACY_UNITS = (
    "xiangyong",
    "gongshou",
    "longdeng",
    "tengpai",
    "huochong",
    "jinshi",
    "wokou_scout",
    "wokou_gun",
    "wokou_ronin",
    "wokou_shield",
    "wokou_chief",
)
LEGAL_SOURCES = {
    "LICENSE": GAME / "LICENSE",
    "NOTICE": GAME / "NOTICE",
    "LICENSE-CC-BY-4.0.txt": GAME / "LICENSE-CC-BY-4.0.txt",
    "assets/audio/LICENSES.md": GAME / "assets/audio/LICENSES.md",
    "assets/fonts/OFL.txt": GAME / "assets/fonts/OFL.txt",
    "assets/icons/game_icons/ATTRIBUTION.md": GAME / "assets/icons/game_icons/ATTRIBUTION.md",
    "assets/icons/game_icons/LICENSE-CC-BY-3.0.txt": GAME / "assets/icons/game_icons/LICENSE-CC-BY-3.0.txt",
    "assets/fx/jeff_fx/LICENSE.txt": GAME / "assets/fx/jeff_fx/LICENSE.txt",
}
RESULTS: dict = {"started_at": dt.datetime.now().astimezone().isoformat(), "checks": {}}


def now() -> str:
    return dt.datetime.now().astimezone().isoformat()


def project_version() -> str:
    text = (GAME / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'(?m)^config/version="([^"]+)"$', text)
    if not match:
        raise RuntimeError("game/project.godot is missing application config/version")
    return match.group(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def save_results(output: Path) -> None:
    RESULTS["updated_at"] = now()
    temporary = output / "release-results.json.tmp"
    temporary.write_text(json.dumps(RESULTS, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, output / "release-results.json")


def run(
    name: str,
    args: list[str],
    output: Path,
    timeout: int = 240,
    cwd: Path = ROOT,
    env_extra: dict[str, str] | None = None,
    markers: tuple[str, ...] = (),
) -> dict:
    environment = os.environ.copy()
    if env_extra:
        environment.update(env_extra)
    logs = output / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    log_path = logs / f"{name}.log"
    command = [str(value) for value in args]
    started = time.monotonic()
    with log_path.open("w", encoding="utf-8") as log:
        log.write("$ " + " ".join(command) + "\n")
        log.flush()
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            start_new_session=True,
        )
        timed_out = False
        try:
            text, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                text, _ = process.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                text, _ = process.communicate()
        log.write(text)
    missing_markers = [marker for marker in markers if marker not in text]
    errors = [
        line
        for line in text.splitlines()
        if "SCRIPT ERROR:" in line or "Failed to instantiate" in line or "Cannot open include file" in line
    ]
    result = {
        "command": command,
        "returncode": process.returncode,
        "timed_out": timed_out,
        "duration_seconds": round(time.monotonic() - started, 3),
        "missing_markers": missing_markers,
        "errors": errors,
        "log": f"logs/{log_path.name}",
    }
    result["passed"] = not timed_out and process.returncode == 0 and not missing_markers and not errors
    RESULTS["checks"][name] = result
    save_results(output)
    if not result["passed"]:
        print(f"--- {name} log (last 160 lines) ---", file=sys.stderr)
        print("\n".join(text.splitlines()[-160:]), file=sys.stderr)
        raise RuntimeError(f"{name} failed; see {log_path}")
    return result


def parse_gut_summary(text: str) -> dict:
    values = {}
    for key, pattern in (
        ("scripts", r"(?m)^Scripts\s+(\d+)\s*$"),
        ("tests", r"(?m)^Tests\s+(\d+)\s*$"),
        ("passed", r"(?m)^Passing Tests\s+(\d+)\s*$"),
        ("asserts", r"(?m)^Asserts\s+(\d+)\s*$"),
    ):
        match = re.search(pattern, text)
        if not match:
            raise RuntimeError(f"GUT summary missing {key}")
        values[key] = int(match.group(1))
    values["framework"] = "GUT 9.7.1"
    values["passed"] = values["tests"] == values["passed"]
    return values


def pck_entries(data: bytes) -> list[dict]:
    if len(data) < 40 or data[:4] != b"GDPC":
        raise ValueError("not a Godot PCK")
    version = struct.unpack_from("<I", data, 4)[0]
    if version != 4:
        raise ValueError(f"unsupported PCK version {version}")
    file_base = struct.unpack_from("<Q", data, 24)[0]
    directory_offset = struct.unpack_from("<Q", data, 32)[0]
    if directory_offset + 4 > len(data):
        raise ValueError("PCK directory offset outside file")
    count = struct.unpack_from("<I", data, directory_offset)[0]
    offset = directory_offset + 4
    if count > 1_000_000:
        raise ValueError(f"implausible PCK entry count {count}")
    entries = []
    for _ in range(count):
        if offset + 4 > len(data):
            raise ValueError("truncated PCK entry length")
        length = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        if length > len(data) - offset:
            raise ValueError("truncated PCK entry path")
        raw = data[offset : offset + length].split(b"\0", 1)[0]
        offset += length
        if offset + 36 > len(data):
            raise ValueError("truncated PCK entry metadata")
        file_offset, file_size = struct.unpack_from("<QQ", data, offset)
        file_offset += file_base
        expected_md5 = data[offset + 16 : offset + 32]
        offset += 36
        if file_offset > len(data) or file_size > len(data) - file_offset:
            raise ValueError(f"PCK entry outside file: {raw!r}")
        content = data[file_offset : file_offset + file_size]
        entries.append(
            {
                "name": raw.decode("utf-8"),
                "size": file_size,
                "md5_valid": hashlib.md5(content, usedforsecurity=False).digest() == expected_md5,
                "sha256": hashlib.sha256(content).hexdigest(),
                "header": content[:4],
            }
        )
    if offset > len(data):
        raise ValueError("PCK directory extends past end of file")
    return entries


def voice_ogg_paths() -> set[str]:
    paths: set[str] = set()

    def walk(value) -> None:
        if isinstance(value, dict):
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
        elif isinstance(value, str) and value.lower().endswith(".ogg"):
            paths.add(value.removeprefix("res://"))

    walk(json.loads((GAME / "data/voice_lines.json").read_text(encoding="utf-8")))
    return paths


def legacy_unit_path(name: str) -> bool:
    normalized = name.removeprefix("watch-yongchang/")
    legacy_static = (
        normalized.startswith("assets/units/")
        and normalized.endswith("/static.png")
        and not normalized.startswith(("assets/units/forge/", "assets/units/towers/"))
    )
    return legacy_static or any(normalized.startswith(f"assets/units/{unit}/") for unit in LEGACY_UNITS)


def forbidden_runtime_path(name: str, source_package: bool = False) -> bool:
    normalized = name.removeprefix("watch-yongchang/")
    tokens = FORBIDDEN_SOURCE_PARTS if source_package else FORBIDDEN_PARTS
    return (
        any(token in normalized for token in tokens)
        or any(part in {"build", "export"} for part in PurePosixPath(normalized).parts)
        or (not source_package and "tests" in PurePosixPath(normalized).parts)
        or legacy_unit_path(normalized)
    )


def audit_pck(label: str, data: bytes, output: Path) -> dict:
    entries = pck_entries(data)
    normalized = [entry["name"].removeprefix("res://") for entry in entries]
    voice_paths = voice_ogg_paths()
    voice = [
        name
        for name in normalized
        if name in voice_paths
        or (("/voice/" in name or PurePosixPath(name).name.startswith("voice_")) and name.lower().endswith(".ogg"))
    ]
    duplicates = sorted(name for name, count in Counter(normalized).items() if count > 1)
    by_name = {entry["name"].removeprefix("res://"): entry for entry in entries}
    project_binary = by_name.get("project.binary")
    legal_mismatches = [
        name
        for name, source in LEGAL_SOURCES.items()
        if name in by_name and by_name[name]["sha256"] != sha256(source)
    ]
    project_valid = (
        project_binary is not None
        and project_binary["size"] > 0
        and project_binary["header"] == b"ECFG"
    )
    result = {
        "passed": project_valid
        and not [name for name in normalized if forbidden_runtime_path(name)]
        and not voice
        and not (REQUIRED_PCK - set(normalized))
        and not duplicates
        and not [entry["name"] for entry in entries if not entry["md5_valid"]]
        and b"GdaHarness=" not in data
        and not legal_mismatches,
        "format_version": 4,
        "file_count": len(normalized),
        "forbidden": [name for name in normalized if forbidden_runtime_path(name)],
        "voice_ogg": voice,
        "missing_legal_files": sorted(REQUIRED_PCK - set(normalized)),
        "duplicate_paths": duplicates,
        "invalid_md5": [entry["name"] for entry in entries if not entry["md5_valid"]],
        "packaged_gda_harness": b"GdaHarness=" in data,
        "project_present": "project.godot" in by_name,
        "project_binary_present": project_binary is not None,
        "project_binary_size": project_binary["size"] if project_binary else 0,
        "project_binary_header": project_binary["header"].hex() if project_binary else "",
        "project_binary_valid": project_valid,
        "legal_byte_mismatches": legal_mismatches,
        "exported_scene_cache_count": sum(name.startswith(".godot/exported/") for name in normalized),
    }
    RESULTS["checks"][label] = result
    save_results(output)
    if not result["passed"]:
        raise RuntimeError(f"{label} audit failed")
    return result


def sensitive_names(entries: list[tuple[str, Path]]) -> list[str]:
    bad = []
    for name, _ in entries:
        base = PurePosixPath(name).name.lower()
        if base == ".env" or base.startswith(".env.") or base in {"id_rsa", "id_ed25519", "credentials.json"}:
            bad.append(name)
        elif base.endswith((".pem", ".key", ".p12", ".pfx")):
            bad.append(name)
    return bad


def zip_audit(path: Path, source_package: bool, output: Path, required: tuple[str, ...] = ()) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        crc_error = archive.testzip()
        unsafe = [
            name
            for name in names
            if PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts or "\\" in name
        ]
        forbidden = [name for name in names if forbidden_runtime_path(name, source_package)]
        entries = [(name, Path(name)) for name in names]
        sensitive = sensitive_names(entries)
        harness = False
        if "watch-yongchang/project.godot" in names:
            harness = b"GdaHarness=" in archive.read("watch-yongchang/project.godot")
        result = {
            "passed": crc_error is None
            and len(names) == len(set(names))
            and not unsafe
            and not forbidden
            and not sensitive
            and not [name for name in required if name not in names]
            and not harness,
            "file_count": len(names),
            "crc_error": crc_error,
            "duplicates": len(names) - len(set(names)),
            "unsafe_names": unsafe,
            "forbidden": forbidden,
            "sensitive_filenames": sensitive,
            "missing_required": [name for name in required if name not in names],
            "packaged_gda_harness": harness,
        }
    RESULTS["checks"][f"zip:{path.name}"] = result
    save_results(output)
    if not result["passed"]:
        raise RuntimeError(f"ZIP audit failed: {path.name}")
    return result


def write_zip(
    path: Path,
    entries: list[tuple[str, Path]],
    stored_suffixes: set[str],
    output: Path,
    source_package: bool = False,
    required: tuple[str, ...] = (),
) -> dict:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    with zipfile.ZipFile(temporary, "w", allowZip64=True) as archive:
        for archive_name, source in sorted(entries):
            info = zipfile.ZipInfo(archive_name, ZIP_STAMP)
            mode = 0o755 if source.stat().st_mode & stat.S_IXUSR else 0o644
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_STORED if source.suffix.lower() in stored_suffixes else zipfile.ZIP_DEFLATED
            archive.writestr(info, source.read_bytes(), compress_type=info.compress_type, compresslevel=6)
    os.replace(temporary, path)
    return zip_audit(path, source_package, output, required)


def source_entries() -> tuple[list[tuple[str, Path]], list[str]]:
    process = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    names = [name.decode("utf-8") for name in process.stdout.split(b"\0") if name]
    entries = []
    missing = []
    for name in sorted(set(names)):
        path = ROOT / name
        if path.is_symlink():
            target = path.resolve(strict=True)
            if not target.is_relative_to(ROOT):
                raise RuntimeError(f"external symlink in source package: {name}")
            target_name = target.relative_to(ROOT).as_posix()
            target_packaged = target.is_file() or any(
                tracked == target_name or tracked.startswith(target_name + "/")
                for tracked in names
            )
            if not target_packaged:
                raise RuntimeError(f"symlink target is not packaged: {name}")
            if target.is_file():
                entries.append((f"watch-yongchang/{name}", target))
            continue
        if not path.is_file():
            missing.append(name)
            continue
        entries.append((f"watch-yongchang/{name}", path))
    return entries, missing


def legal_entries(output: Path) -> list[tuple[str, Path]]:
    names = [
        "README.md",
        "DORA.md",
        "LICENSE",
        "NOTICE",
        "LICENSE-CC-BY-4.0.txt",
        "AI使用与素材声明.md",
        "素材授权清单.csv",
        "docs/edgeone-deploy.md",
        "docs/文化来源.md",
        "game/LICENSE",
        "game/NOTICE",
        "game/LICENSE-CC-BY-4.0.txt",
        "game/data/credits.json",
        "game/assets/audio/LICENSES.md",
        "game/assets/fonts/OFL.txt",
        "game/assets/icons/game_icons/ATTRIBUTION.md",
        "game/assets/icons/game_icons/LICENSE-CC-BY-3.0.txt",
        "game/assets/fx/jeff_fx/LICENSE.txt",
    ]
    entries = [(name, ROOT / name) for name in names]
    entries.append(("assets/fonts/OFL.txt", GAME / "assets/fonts/OFL.txt"))
    entries.extend(
        [
            ("RELEASE-README.md", output / "RELEASE-README.md"),
            ("CI-BUILD-REPORT.md", output / "CI-BUILD-REPORT.md"),
        ]
    )
    return entries


def artifact_record(path: Path, role: str) -> dict:
    return {"name": path.name, "role": role, "size_bytes": path.stat().st_size, "sha256": sha256(path)}


def process_snapshot() -> list[str]:
    process = subprocess.run(["ps", "-eo", "pid=,comm=,args="], capture_output=True, text=True, check=False)
    rows = []
    for line in process.stdout.splitlines():
        lowered = line.lower()
        if any(token in lowered for token in ("godot_v4", "gda.daemon", "xvfb :99", "wineserver")):
            if "tools/release.py" not in line and "ps -eo" not in line:
                rows.append(line.strip())
    return rows


def release_readme(output: Path, commit: str, godot_version: str, game_version: str) -> None:
    run_url = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    repository = os.environ.get("GITHUB_REPOSITORY", "xingwangzhe/watch-yongchang")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    ci_link = f"{run_url}/{repository}/actions/runs/{run_id}" if run_id else "GitHub Actions release.yml"
    ci_line = f"- 构建证据：[{ci_link}]({ci_link})" if run_id else "- 构建证据：GitHub Actions `release.yml`"
    text = f"""# 《守望 · 永昌》发布包

- 版本：`v{game_version}`
- 提交：`{commit}`
- Godot：`{godot_version}`
{ci_line}

## 桌面运行

- Linux：解压后执行 `./watch-yongchang-linux.x86_64`。
- Windows：解压后执行 `watch-yongchang.exe`。
- macOS：解压 ZIP 后运行 `.app`；本包未签名，首次打开可能需要系统允许。

Linux / Windows 的可执行文件和同名 `.pck` 必须放在同一目录。完整说明见 `README.md`。

## Dora SSR 兼容

Dora 适配入口与构建器保留在源码中，发布前只做静态兼容检查。本 GitHub Release 不发布 Dora 运行时包，发布路径为 Godot 原生桌面三平台导出与 Web 静态导出。

## 文件

- `watch-yongchang-linux.x86_64` / `.pck`
- `watch-yongchang-windows.exe` / `.pck`
- `watch-yongchang-macos.zip`
- `watch-yongchang-linux.zip` / `watch-yongchang-windows.zip`
- `watch-yongchang-source.zip`
- `release-manifest.json`、`SHA256SUMS.txt`、`CI-BUILD-REPORT.md`

## 授权

项目代码采用 AGPL-3.0-or-later；团队原创非代码资产采用 CC BY 4.0；特定原创音频可选择 CC0 或 CC BY 4.0；第三方内容、字体和运行库保留各自许可。范围与署名见 `LICENSE`、`LICENSE-CC-BY-4.0.txt`、`NOTICE`、`AI使用与素材声明.md` 和 `素材授权清单.csv`。
"""
    (output / "RELEASE-README.md").write_text(text, encoding="utf-8")


def build_report(output: Path, tests: dict, commit: str, game_version: str) -> None:
    rows = [
        "# CI 发布构建报告",
        "",
        f"- 版本：`v{game_version}`",
        f"- 提交：`{commit}`",
        f"- Godot：`{(GAME / '.godot-version').read_text(encoding='utf-8').strip()}`",
    ]
    if tests:
        rows.append(f"- GUT：**{tests['tests']} / {tests['tests']} passed / {tests['asserts']} asserts**")
    rows.extend(["", "| 检查 | 结果 |", "|---|---|"])
    for name, value in RESULTS["checks"].items():
        rows.append(f"| `{name}` | {'PASS' if value.get('passed') else 'FAIL'} |")
    rows.extend(
        [
            "",
            "本工作流完成桌面三平台与 Web 导出、PCK v4 内容/MD5/法律文件审计、ZIP CRC/路径/敏感文件名审计、Linux 发行版启动 smoke 与哈希清单。",
            "原生 Windows GUT 由独立 `verify.yml` 验证；macOS 仅做结构与内嵌 PCK 审计，未在 macOS 实机运行；Dora 适配仅做静态兼容检查，不作为 GitHub Release 发布路径。",
            "",
        ]
    )
    (output / "CI-BUILD-REPORT.md").write_text("\n".join(rows), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    godot = args.godot.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, capture_output=True, text=True).stdout.strip()
    godot_version = (GAME / ".godot-version").read_text(encoding="utf-8").strip()
    game_version = project_version()
    tag = os.environ.get("GITHUB_REF_NAME", "")
    if os.environ.get("GITHUB_REF_TYPE") == "tag" and tag != f"v{game_version}":
        raise RuntimeError(f"release tag {tag} does not match game version v{game_version}")
    RESULTS["game_version"] = game_version
    save_results(output)
    run("dora-static-check", ["python3", "dora/build.py", "--check"], output)
    run("import", [godot, "--headless", "--path", "game", "--import"], output, timeout=300)
    gut = run(
        "gut-full",
        [godot, "--headless", "--path", "game", "-s", "addons/gut/gut_cmdln.gd", "-gdir=res://tests/unit", "-gexit"],
        output,
        timeout=600,
        markers=("All tests passed!",),
    )
    tests = parse_gut_summary((output / gut["log"]).read_text(encoding="utf-8", errors="replace"))
    RESULTS["tests"] = tests
    save_results(output)

    for directory in ("linux", "windows", "macos"):
        (GAME / "build" / directory).mkdir(parents=True, exist_ok=True)
    for preset in ("Linux", "Windows", "macOS"):
        run(f"export-{preset.lower()}", [godot, "--headless", "--path", "game", "--export-release", preset], output, timeout=600)

    exported = {
        "watch-yongchang-linux.x86_64": GAME / "build/linux/watch-yongchang.x86_64",
        "watch-yongchang-linux.pck": GAME / "build/linux/watch-yongchang.pck",
        "watch-yongchang-windows.exe": GAME / "build/windows/watch-yongchang.exe",
        "watch-yongchang-windows.pck": GAME / "build/windows/watch-yongchang.pck",
        "watch-yongchang-macos.zip": GAME / "build/macos/watch-yongchang.zip",
    }
    for name, source in exported.items():
        if not source.is_file():
            raise RuntimeError(f"export did not create {source}")
        shutil.copy2(source, output / name)

    audit_pck("pck:linux", (output / "watch-yongchang-linux.pck").read_bytes(), output)
    audit_pck("pck:windows", (output / "watch-yongchang-windows.pck").read_bytes(), output)

    with zipfile.ZipFile(output / "watch-yongchang-macos.zip") as archive:
        pck_members = [
            name for name in archive.namelist() if ".app/Contents/Resources/" in name and name.endswith(".pck")
        ]
        executables = [
            name for name in archive.namelist() if ".app/Contents/MacOS/" in name and not name.endswith("/")
        ]
        if len(pck_members) != 1 or len(executables) != 1:
            raise RuntimeError(f"macOS bundle layout invalid: pck={pck_members}, executables={executables}")
        audit_pck("pck:macos", archive.read(pck_members[0]), output)
    zip_audit(output / "watch-yongchang-macos.zip", False, output)
    binary_harness = {
        "linux": b"GdaHarness=" in (output / "watch-yongchang-linux.x86_64").read_bytes(),
        "windows": b"GdaHarness=" in (output / "watch-yongchang-windows.exe").read_bytes(),
    }
    with zipfile.ZipFile(output / "watch-yongchang-macos.zip") as archive:
        binary_harness["macos"] = any(b"GdaHarness=" in archive.read(name) for name in executables)
    RESULTS["checks"]["binary-harness"] = {"passed": not any(binary_harness.values()), "found": binary_harness}
    save_results(output)
    if any(binary_harness.values()):
        raise RuntimeError("GdaHarness marker found in release executable")

    smoke_home = output / "smoke-home"
    smoke_home.mkdir(exist_ok=True)
    run(
        "linux-release-smoke",
        [
            output / "watch-yongchang-linux.x86_64",
            "--headless",
            "--quit-after",
            "8",
            "--audio-driver",
            "Dummy",
            "--rendering-method",
            "gl_compatibility",
        ],
        output,
        timeout=120,
        cwd=output,
        env_extra={
            "HOME": str(smoke_home),
            "XDG_DATA_HOME": str(smoke_home / "data"),
            "XDG_CONFIG_HOME": str(smoke_home / "config"),
            "WATCH_SETTINGS_PATH": str(smoke_home / "settings.cfg"),
            "WATCH_RENDERER": "opengl",
            "TMPDIR": str(output),
        },
    )

    release_readme(output, commit, godot_version, game_version)
    build_report(output, tests, commit, game_version)
    legal = legal_entries(output)
    stored = {".exe", ".x86_64", ".pck", ".zip", ".png", ".jpg", ".jpeg", ".ogg", ".ttf", ".woff2"}
    common_required = (
        "RELEASE-README.md",
        "CI-BUILD-REPORT.md",
        "README.md",
        "LICENSE",
        "NOTICE",
        "LICENSE-CC-BY-4.0.txt",
    )
    write_zip(
        output / "watch-yongchang-linux.zip",
        legal
        + [
            ("watch-yongchang-linux.x86_64", output / "watch-yongchang-linux.x86_64"),
            ("watch-yongchang-linux.pck", output / "watch-yongchang-linux.pck"),
        ],
        stored,
        output,
        required=common_required + ("watch-yongchang-linux.x86_64", "watch-yongchang-linux.pck"),
    )
    write_zip(
        output / "watch-yongchang-windows.zip",
        legal
        + [
            ("watch-yongchang-windows.exe", output / "watch-yongchang-windows.exe"),
            ("watch-yongchang-windows.pck", output / "watch-yongchang-windows.pck"),
        ],
        stored,
        output,
        required=common_required + ("watch-yongchang-windows.exe", "watch-yongchang-windows.pck"),
    )

    entries, missing = source_entries()
    if missing:
        raise RuntimeError(f"tracked source files missing from working tree: {missing}")
    write_zip(
        output / "watch-yongchang-source.zip",
        entries,
        stored,
        output,
        source_package=True,
        required=("watch-yongchang/README.md", "watch-yongchang/LICENSE", "watch-yongchang/dora/init.lua"),
    )
    build_report(output, tests, commit, game_version)

    RESULTS["processes_after_cleanup"] = process_snapshot()
    RESULTS["finished_at"] = now()
    save_results(output)
    if RESULTS["processes_after_cleanup"]:
        raise RuntimeError(f"engine processes remain after release build: {RESULTS['processes_after_cleanup']}")

    artifact_names = [
        "watch-yongchang-linux.x86_64",
        "watch-yongchang-linux.pck",
        "watch-yongchang-windows.exe",
        "watch-yongchang-windows.pck",
        "watch-yongchang-macos.zip",
        "watch-yongchang-linux.zip",
        "watch-yongchang-windows.zip",
        "watch-yongchang-source.zip",
        "RELEASE-README.md",
        "CI-BUILD-REPORT.md",
    ]
    records = [artifact_record(output / name, "release") for name in artifact_names]
    manifest = {
        "schema_version": 2,
        "project": "守望 · 永昌 / Watch of Yongchang",
        "generated_at": RESULTS["finished_at"],
        "commit": commit,
        "game_version": game_version,
        "godot_version": godot_version,
        "tests": tests,
        "artifacts": records,
        "checks": RESULTS["checks"],
        "processes_after_cleanup": RESULTS["processes_after_cleanup"],
        "pending_external_acceptance": [
            "native Windows release execution",
            "macOS hardware run",
            "AtomGit mirror",
            "Bilibili upload with competition tag",
            "原子派 publication and 20 likes",
            "competition submission",
            "competition peer review",
        ],
    }
    manifest_path = output / "release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    checksum_names = artifact_names + ["release-manifest.json", "release-results.json"]
    sums = [f"{sha256(output / name)}  {name}" for name in checksum_names]
    (output / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
