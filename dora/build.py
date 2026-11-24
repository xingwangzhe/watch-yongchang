#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Build a Dora SSR source ZIP without launching Godot or Dora.

The archive contains init.lua at its root and the imported Godot project under
watch-yongchang/. Only imported outputs referenced by current .import sidecars
are copied; stale editor/import-cache files are never swept into the package.
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
PROJECT_DIR = "watch-yongchang"
DEFAULT_OUTPUT = ROOT / "artifacts" / "watch-yongchang-dora.zip"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
ROOT_DOCUMENTS = (
    "DORA.md",
    "LICENSE",
    "NOTICE",
    "LICENSE-CC-BY-4.0.txt",
    "AI使用与素材声明.md",
    "素材授权清单.csv",
)
EXCLUDED_TOP_LEVEL = {"tests", "build", "export"}
EXCLUDED_ADDONS = {"addons/gut", "addons/gda_harness"}
CACHE_FILES = (".gdignore", "global_script_class_cache.cfg", "uid_cache.bin")
FORBIDDEN_PREFIXES = (
    f"{PROJECT_DIR}/tests/",
    f"{PROJECT_DIR}/build/",
    f"{PROJECT_DIR}/export/",
    f"{PROJECT_DIR}/addons/gut/",
    f"{PROJECT_DIR}/addons/gda_harness/",
    f"{PROJECT_DIR}/.godot/editor/",
    f"{PROJECT_DIR}/.godot/exported/",
    f"{PROJECT_DIR}/.godot/shader_cache/",
)


class BuildError(RuntimeError):
    pass


def read_utf8(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise BuildError(f"cannot read {path.relative_to(ROOT)}: {exc}") from exc


def setting(text: str, section: str, key: str) -> str:
    current = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
        elif current == section and line.startswith(key + "="):
            return line.split("=", 1)[1].strip().strip('"')
    return ""


def section_entries(text: str, section: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    current = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
        elif current == section and line and not line.startswith((";", "#")):
            if "=" in line:
                name, value = line.split("=", 1)
                entries.append((name.strip(), value.strip().strip('"')))
    return entries


def resource_path(value: str, label: str) -> str:
    if not value.startswith("res://"):
        raise BuildError(f"{label} is not a res:// path: {value!r}")
    path = PurePosixPath(value.removeprefix("res://"))
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise BuildError(f"unsafe resource path in {label}: {value!r}")
    return path.as_posix()


def require_source_file(files: set[str], value: str, label: str) -> None:
    relative = resource_path(value, label)
    if relative not in files:
        raise BuildError(f"{label} points to missing or excluded file: {relative}")


def validate_project(project_text: str, files: set[str]) -> None:
    version = read_utf8(GAME / ".godot-version").strip()
    if not re.fullmatch(r"4\.\d+\.\d+(?:-[A-Za-z0-9.]+)?", version):
        raise BuildError(f"expected a stable Godot 4 version, got {version!r}")
    if "[dotnet]" in project_text:
        raise BuildError("C#/.NET projects are not supported by this GDScript adapter")

    features = setting(project_text, "application", "config/features")
    if '"4.' not in features or "GL Compatibility" not in features:
        raise BuildError("project.godot must declare Godot 4 GL Compatibility")
    if setting(project_text, "rendering", "renderer/rendering_method") != "gl_compatibility":
        raise BuildError("Dora adapter expects the gl_compatibility renderer")

    main_scene = setting(project_text, "application", "run/main_scene")
    if not main_scene:
        raise BuildError("project.godot has no run/main_scene")
    require_source_file(files, main_scene, "run/main_scene")

    autoloads = section_entries(project_text, "autoload")
    for name, value in autoloads:
        if not value.startswith("*"):
            raise BuildError(f"runtime autoload {name} is disabled")
        script = value[1:].strip('"')
        if name == "GdaHarness":
            if script != "res://addons/gda_harness/gda_harness.gd":
                raise BuildError("unexpected GdaHarness script path")
            continue
        require_source_file(files, script, f"autoload {name}")

    font = setting(project_text, "gui", "theme/custom_font")
    if font:
        require_source_file(files, font, "global theme font")

    for relative in sorted(files):
        if relative.endswith((".cs", ".gdextension")):
            raise BuildError(f"unsupported native/C# input: {relative}")

    init = read_utf8(ROOT / "dora" / "init.lua")
    for token in (
        'require("Dora")',
        'local PROJECT_PATH = "watch-yongchang"',
        "Dora.GodotNode.getUnsupportedReason()",
        'Dora.GodotNode(PROJECT_PATH, "",',
        "Dora.Director.ui",
        "game:schedule",
        "game.lastError",
        "game.running",
    ):
        if token not in init:
            raise BuildError(f"dora/init.lua is missing required startup logic: {token}")


def collect_game_files() -> set[str]:
    files: set[str] = set()
    for path in sorted(GAME.rglob("*")):
        relative = path.relative_to(GAME)
        parts = relative.parts
        if not parts or parts[0] == ".godot":
            continue
        if parts[0] in EXCLUDED_TOP_LEVEL or "__pycache__" in parts:
            continue
        relative_text = relative.as_posix()
        if any(relative_text == item or relative_text.startswith(item + "/") for item in EXCLUDED_ADDONS):
            continue
        if path.name in {".DS_Store", "Thumbs.db"}:
            continue
        if path.is_symlink():
            raise BuildError(f"symlinks are not allowed in source package: {relative_text}")
        if path.is_file():
            files.add(relative_text)
    return files


def package_project_text(project_text: str) -> str:
    harness_line = 'GdaHarness="*res://addons/gda_harness/gda_harness.gd"'
    lines = project_text.splitlines(keepends=True)
    kept = [line for line in lines if line.strip() != harness_line]
    if kept == lines:
        return project_text
    return "".join(kept)


def add_cache_file(entries: dict[str, Path], relative: str, required: bool) -> None:
    path = GAME / ".godot" / relative
    if path.is_symlink():
        raise BuildError(f"symlink in Godot cache: {path.relative_to(ROOT)}")
    if not path.is_file():
        if required:
            raise BuildError(
                f"missing {path.relative_to(ROOT)}; run the documented Godot import first"
            )
        return
    entries[f"{PROJECT_DIR}/.godot/{relative}"] = path


def collect_imported_files(files: set[str]) -> set[str]:
    cache = GAME / ".godot" / "imported"
    if not cache.is_dir():
        raise BuildError("missing game/.godot/imported; run the documented Godot import first")

    sidecars = sorted(relative for relative in files if relative.endswith(".import"))
    if not sidecars:
        raise BuildError("no asset .import sidecars found")

    outputs: set[str] = set()
    imported_output_count = 0
    for sidecar in sidecars:
        sidecar_text = read_utf8(GAME / sidecar)
        references: set[str] = set()
        for section in ("remap", "deps"):
            match = re.search(
                rf"(?ms)^\[{re.escape(section)}\][ \t]*\r?\n(.*?)(?=^\[|\Z)",
                sidecar_text,
            )
            if match:
                references.update(re.findall(r'"(res://[^"]+)"', match.group(1)))

        for reference in sorted(references):
            relative = resource_path(reference, f"{sidecar} import output")
            target = GAME / relative
            if target.is_symlink():
                raise BuildError(f"symlink in imported resource: {relative}")
            if not target.is_file():
                raise BuildError(f"missing imported resource referenced by {sidecar}: {relative}")
            outputs.add(relative)
            if relative.startswith(".godot/imported/"):
                imported_output_count += 1
                md5 = target.with_name(target.name + ".md5")
                if md5.is_symlink():
                    raise BuildError(f"symlink in imported checksum: {relative}.md5")
                if md5.is_file():
                    outputs.add(relative + ".md5")

    if imported_output_count == 0:
        raise BuildError("import cache has no referenced .godot/imported outputs")
    return outputs


def validate_entry_name(name: str) -> None:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name:
        raise BuildError(f"unsafe ZIP entry name: {name!r}")
    if any(name.startswith(prefix) for prefix in FORBIDDEN_PREFIXES):
        raise BuildError(f"development-only ZIP entry: {name}")


def collect_entries() -> tuple[dict[str, Path | bytes], int]:
    files = collect_game_files()
    project_text = read_utf8(GAME / "project.godot")
    validate_project(project_text, files)
    packaged_project = package_project_text(project_text)

    for document in ROOT_DOCUMENTS:
        path = ROOT / document
        if path.is_symlink() or not path.is_file():
            raise BuildError(f"missing required package document: {document}")

    entries: dict[str, Path | bytes] = {}
    init_path = ROOT / "dora" / "init.lua"
    entries["init.lua"] = init_path
    for document in ROOT_DOCUMENTS:
        entries[document] = ROOT / document
    for relative in sorted(files):
        archive_name = f"{PROJECT_DIR}/{relative}"
        entries[archive_name] = (
            packaged_project.encode("utf-8")
            if relative == "project.godot"
            else GAME / relative
        )

    for relative in CACHE_FILES:
        add_cache_file(entries, relative, required=relative in {".gdignore", "global_script_class_cache.cfg"})

    imported_files = collect_imported_files(files)
    for relative in sorted(imported_files):
        archive_name = f"{PROJECT_DIR}/{relative}"
        validate_entry_name(archive_name)
        entries.setdefault(archive_name, GAME / relative)

    for name in entries:
        validate_entry_name(name)
    for name in entries:
        if name.endswith(".import") and name[:-7] not in entries:
            raise BuildError(f"import sidecar has no packaged source asset: {name}")
    return entries, len([name for name in files if name.endswith(".import")])


def verify_zip(path: Path, expected_names: set[str]) -> None:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise BuildError("ZIP contains duplicate entries")
        if set(names) != expected_names:
            missing = sorted(expected_names - set(names))
            extra = sorted(set(names) - expected_names)
            raise BuildError(f"ZIP layout mismatch; missing={missing}, extra={extra}")
        bad = archive.testzip()
        if bad is not None:
            raise BuildError(f"ZIP CRC check failed: {bad}")
        for name in names:
            validate_entry_name(name)
        required = {"init.lua", f"{PROJECT_DIR}/project.godot", *ROOT_DOCUMENTS}
        if not required.issubset(names):
            raise BuildError("ZIP is missing required root files")
        project_text = archive.read(f"{PROJECT_DIR}/project.godot").decode("utf-8")
        if 'GdaHarness="*res://addons/gda_harness/gda_harness.gd"' in project_text:
            raise BuildError("packaged project still enables GdaHarness")
        for name in names:
            if name.endswith(".import") and name[:-7] not in expected_names:
                raise BuildError(f"ZIP import sidecar has no source asset: {name}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def build(output: Path) -> None:
    output = output if output.is_absolute() else ROOT / output
    output = output.resolve()
    try:
        output.relative_to(GAME.resolve())
    except ValueError:
        pass
    else:
        raise BuildError("ZIP output must be outside game/ so it cannot package itself")

    entries, sidecar_count = collect_entries()
    output.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=output.name + ".", suffix=".tmp", dir=output.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name in sorted(entries):
                info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | 0o644) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                value = entries[name]
                data = value if isinstance(value, bytes) else value.read_bytes()
                archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
        verify_zip(temporary, set(entries))
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)

    size_mib = output.stat().st_size / (1024 * 1024)
    try:
        display_path = output.relative_to(ROOT)
    except ValueError:
        display_path = output
    print(f"Built {display_path} ({len(entries)} files, {sidecar_count} import sidecars, {size_mib:.2f} MiB)")
    print(f"sha256={sha256(output)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="run static checks without reading the import cache")
    mode.add_argument("--output", type=Path, help="ZIP path (default: artifacts/watch-yongchang-dora.zip)")
    args = parser.parse_args()

    try:
        if args.check:
            files = collect_game_files()
            validate_project(read_utf8(GAME / "project.godot"), files)
            for document in ROOT_DOCUMENTS:
                if not (ROOT / document).is_file():
                    raise BuildError(f"missing required package document: {document}")
            print(f"Dora static checks passed ({len(files)} source files).")
        else:
            build(args.output or DEFAULT_OUTPUT)
    except (BuildError, OSError, zipfile.BadZipFile) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
