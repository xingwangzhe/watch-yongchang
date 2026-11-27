#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import zipfile

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import release as r


WEB_REQUIRED = ("index.html", "index.js", "index.wasm", "index.pck")
WEB_CHECK_MARKER = "WEB_BUILD_CHECKS_OK"
ANDROID_CHECK_MARKER = "ANDROID_BUILD_CHECKS_OK"


def require_file(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"missing release input: {path}")


def read_tests(root: Path) -> dict:
    log = root / "gut" / "gut.log"
    require_file(log)
    summary = r.parse_gut_summary(log.read_text(encoding="utf-8", errors="replace"))
    if not summary["passed"]:
        raise RuntimeError(f"GUT quality gate failed: {summary}")
    summary["runner"] = "single GUT quality gate (Linux)"
    summary["log"] = "gut/gut.log"
    return summary


def read_web_checks(root: Path) -> dict:
    log = root / "web" / "build-check.log"
    require_file(log)
    text = log.read_text(encoding="utf-8", errors="replace")
    if WEB_CHECK_MARKER not in text:
        raise RuntimeError(f"Web build checks did not report {WEB_CHECK_MARKER}: {log}")
    return {
        "passed": True,
        "log": "web/build-check.log",
        "marker": WEB_CHECK_MARKER,
    }


def read_android_checks(root: Path) -> dict:
    log = root / "android" / "build-check.log"
    signature_log = root / "android" / "signature-check.log"
    require_file(log)
    require_file(signature_log)
    text = log.read_text(encoding="utf-8", errors="replace")
    signature = signature_log.read_text(encoding="utf-8", errors="replace")
    if ANDROID_CHECK_MARKER not in text:
        raise RuntimeError(f"Android build checks did not report {ANDROID_CHECK_MARKER}: {log}")
    required = (
        "abis=arm64-v8a,armeabi-v7a",
        "min_sdk=24",
        "target_sdk=36",
        f"version={r.project_version()}",
        "package=fun.xingwangzhe.watchyongchang",
        "gamepad_actions=move:left_stick,dpad;attack:A;dash:B;interact:X;codex:Y;auto_attack:Back",
        "gamepad_tests=GUT:test_android_gamepad.gd",
        "signature=verified_debug_key",
    )
    missing = [value for value in required if value not in text]
    if missing:
        raise RuntimeError(f"Android build checks missing required fields: {missing}")
    for scheme in ("v2", "v3"):
        if f"Verified using {scheme} scheme" not in signature or "true" not in signature.split(
            f"Verified using {scheme} scheme", 1
        )[1].splitlines()[0]:
            raise RuntimeError(f"Android APK signature {scheme} verification failed: {signature_log}")
    return {
        "passed": True,
        "log": "android/build-check.log",
        "signature_log": "android/signature-check.log",
        "abis": ["arm64-v8a", "armeabi-v7a"],
        "min_sdk": 24,
        "target_sdk": 36,
        "gamepad_test": "GUT:test_android_gamepad.gd",
        "signature_schemes": ["v2", "v3"],
    }


def copy_artifacts(root: Path, output: Path) -> None:
    mapping = {
        "watch-yongchang-linux.x86_64": root / "linux/watch-yongchang-linux.x86_64",
        "watch-yongchang-linux.pck": root / "linux/watch-yongchang-linux.pck",
        "watch-yongchang-windows.exe": root / "windows/watch-yongchang-windows.exe",
        "watch-yongchang-windows.pck": root / "windows/watch-yongchang-windows.pck",
        "watch-yongchang-macos.zip": root / "macos/watch-yongchang.zip",
        "watch-yongchang-android.apk": root / "android/watch-yongchang-android.apk",
    }
    for name, source in mapping.items():
        require_file(source)
        shutil.copy2(source, output / name)
    (output / "watch-yongchang-linux.x86_64").chmod(0o755)


def audit_desktop(output: Path) -> None:
    r.audit_pck("pck:linux", (output / "watch-yongchang-linux.pck").read_bytes(), output)
    r.audit_pck("pck:windows", (output / "watch-yongchang-windows.pck").read_bytes(), output)
    with zipfile.ZipFile(output / "watch-yongchang-macos.zip") as archive:
        pck_members = [
            name
            for name in archive.namelist()
            if ".app/Contents/Resources/" in name and name.endswith(".pck")
        ]
        executables = [
            name
            for name in archive.namelist()
            if ".app/Contents/MacOS/" in name and not name.endswith("/")
        ]
        if len(pck_members) != 1 or len(executables) != 1:
            raise RuntimeError(
                f"macOS bundle layout invalid: pck={pck_members}, executables={executables}"
            )
        r.audit_pck("pck:macos", archive.read(pck_members[0]), output)
    r.zip_audit(output / "watch-yongchang-macos.zip", False, output)

    binary_harness = {
        "linux": b"GdaHarness=" in (output / "watch-yongchang-linux.x86_64").read_bytes(),
        "windows": b"GdaHarness=" in (output / "watch-yongchang-windows.exe").read_bytes(),
    }
    with zipfile.ZipFile(output / "watch-yongchang-macos.zip") as archive:
        binary_harness["macos"] = any(b"GdaHarness=" in archive.read(name) for name in executables)
    r.RESULTS["checks"]["binary-harness"] = {
        "passed": not any(binary_harness.values()),
        "found": binary_harness,
    }
    r.save_results(output)
    if any(binary_harness.values()):
        raise RuntimeError("GdaHarness marker found in a release executable")


def audit_web(root: Path, output: Path) -> None:
    web = root / "web" / "site"
    for name in WEB_REQUIRED:
        require_file(web / name)
    index = (web / "index.html").read_text(encoding="utf-8")
    if "const GODOT_THREADS_ENABLED = false;" not in index:
        raise RuntimeError("Web export must use the single-thread runtime")
    if '"ensureCrossOriginIsolationHeaders":false' not in index:
        raise RuntimeError("Web export must not require COOP/COEP headers")
    r.audit_pck("pck:web", (web / "index.pck").read_bytes(), output)
    r.RESULTS["checks"]["web-static"] = {
        "passed": True,
        "files": sorted(path.name for path in web.iterdir() if path.is_file()),
        "threads": False,
        "cross_origin_isolation_required": False,
    }
    r.save_results(output)


def audit_android(root: Path, output: Path, android_checks: dict) -> None:
    apk = output / "watch-yongchang-android.apk"
    require_file(apk)
    with zipfile.ZipFile(apk) as archive:
        broken_member = archive.testzip()
        if broken_member:
            raise RuntimeError(f"Android APK ZIP CRC failed at {broken_member}")
        members = set(archive.namelist())
        required = {
            "AndroidManifest.xml",
            "lib/arm64-v8a/libgodot_android.so",
            "lib/armeabi-v7a/libgodot_android.so",
        }
        missing = sorted(required - members)
        if missing:
            raise RuntimeError(f"Android APK is missing required runtime entries: {missing}")
    r.RESULTS["checks"]["android-apk"] = {
        "passed": True,
        "bytes": apk.stat().st_size,
        "abis": android_checks["abis"],
        "min_sdk": android_checks["min_sdk"],
        "target_sdk": android_checks["target_sdk"],
        "signature_schemes": android_checks["signature_schemes"],
        "gamepad_test": android_checks["gamepad_test"],
    }
    r.save_results(output)


def write_readme(output: Path, commit: str, godot_version: str, game_version: str) -> None:
    run_url = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    repository = os.environ.get("GITHUB_REPOSITORY", "xingwangzhe/watch-yongchang")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    ci_link = (
        f"{run_url}/{repository}/actions/runs/{run_id}"
        if run_id
        else "GitHub Actions release.yml"
    )
    ci_line = f"- 构建证据：[{ci_link}]({ci_link})" if run_id else f"- 构建证据：{ci_link}"
    text = f"""# 《守望 · 永昌》发布包

- 版本：`v{game_version}`
- 提交：`{commit}`
- Godot：`{godot_version}`
- Web 在线版：<https://2026shouwang.needhelp.icu>
{ci_line}

## 运行

- Linux：解压后执行 `./watch-yongchang-linux.x86_64`。
- Windows：解压后执行 `watch-yongchang.exe`。
- macOS：解压 ZIP 后运行 `.app`；本包未签名，首次打开可能需要系统允许。
- Android：安装 `watch-yongchang-android.apk`（调试签名，侧载包；不用于应用商店上架）。手机触屏可操作，Android 手柄使用左摇杆/十字键移动、A 攻击、B 冲刺、X 互动、Y 图鉴、Back 切换自动攻击。
- Web：解压 `watch-yongchang-web.zip` 到任意静态目录，或直接使用上面的 EdgeOne Makers 在线版。

Linux / Windows 的可执行文件和同名 `.pck` 必须放在同一目录。Web 构建为单线程导出，
不要求 COOP/COEP 响应头。完整说明见 `README.md`。

## 文件

- `watch-yongchang-linux.x86_64` / `.pck`
- `watch-yongchang-windows.exe` / `.pck`
- `watch-yongchang-macos.zip`
- `watch-yongchang-android.apk`（arm64-v8a、armeabi-v7a，最低 SDK 24）
- `watch-yongchang-web.zip`
- `watch-yongchang-linux.zip` / `watch-yongchang-windows.zip`
- `watch-yongchang-source.zip`
- `release-manifest.json`、`SHA256SUMS.txt`、`CI-BUILD-REPORT.md`

## 授权

项目代码采用 AGPL-3.0-or-later；团队原创非代码资产采用 CC BY 4.0；特定原创音频可选择
CC0 或 CC BY 4.0；第三方内容、字体和运行库保留各自许可。范围与署名见 `LICENSE`、
`LICENSE-CC-BY-4.0.txt`、`NOTICE`、`AI使用与素材声明.md` 和 `素材授权清单.csv`。
"""
    (output / "RELEASE-README.md").write_text(text, encoding="utf-8")


def write_build_report(
    output: Path,
    tests: dict,
    web_checks: dict,
    android_checks: dict,
    commit: str,
    game_version: str,
    godot_version: str,
) -> None:
    rows = [
        "# CI 发布构建报告",
        "",
        f"- 版本：`v{game_version}`",
        f"- 提交：`{commit}`",
        f"- Godot：`{godot_version}`",
        f"- GUT（单次前置门禁）：**{tests['tests']} / {tests['tests']} passed / {tests['asserts']} asserts**",
        f"- Web 构建检查：**PASS**（`{web_checks['log']}`）",
        f"- Android APK/手柄检查：**PASS**（`{android_checks['log']}`；签名 v2/v3，ABI arm64-v8a/armeabi-v7a；设备安装未由 CI 声明）",
        "- 构建拓扑：GUT 先串行通过；Linux、Windows、macOS、Web 与 Android 构建作业再依赖该门禁独立执行，不重复运行 GUT。",
        "",
        "| 门禁 / 平台检查 | 结果 | 日志 |",
        "|---|---|---|",
        f"| GUT 单次前置门禁 | {tests['tests']} / {tests['tests']} PASS | `{tests['log']}` |",
        f"| Web 构建静态检查 | PASS | `{web_checks['log']}` |",
        f"| Android APK、ABI、签名与手柄映射 | PASS | `{android_checks['log']}` |",
    ]
    rows.extend(["", "| 检查 | 结果 |", "|---|---|"])
    for name, value in r.RESULTS["checks"].items():
        rows.append(f"| `{name}` | {'PASS' if value.get('passed') else 'FAIL'} |")
    rows.extend(
        [
            "",
            "发布流程执行五平台原生导出、Windows 原生 smoke、PCK v4 内容/MD5/法律文件审计、",
            "ZIP CRC/路径/敏感文件名审计、Linux 发行版启动 smoke、Web 单线程静态检查、Android APK ABI/签名校验与哈希清单。",
            "Web 产物由 GitHub Actions 使用 `EDGEONE_API_TOKEN` 部署到 EdgeOne Makers 项目 `shouwang`。",
            "",
        ]
    )
    (output / "CI-BUILD-REPORT.md").write_text("\n".join(rows), encoding="utf-8")


def build_web_zip(root: Path, output: Path, legal: list[tuple[str, Path]]) -> None:
    web = root / "web" / "site"
    entries = legal + [(path.name, path) for path in sorted(web.iterdir()) if path.is_file()]
    r.write_zip(
        output / "watch-yongchang-web.zip",
        entries,
        {".png", ".pck", ".wasm"},
        output,
        required=(
            "index.html",
            "index.js",
            "index.wasm",
            "index.pck",
            "README.md",
            "LICENSE",
            "NOTICE",
            "LICENSE-CC-BY-4.0.txt",
        ),
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    root = args.input.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    commit = os.environ.get("GITHUB_SHA", "").strip()
    if not commit:
        commit = __import__("subprocess").run(
            ["git", "rev-parse", "HEAD"], cwd=r.ROOT, check=True, capture_output=True, text=True
        ).stdout.strip()
    godot_version = (r.GAME / ".godot-version").read_text(encoding="utf-8").strip()
    game_version = r.project_version()
    tag = os.environ.get("GITHUB_REF_NAME", "")
    if os.environ.get("GITHUB_REF_TYPE") == "tag" and tag != f"v{game_version}":
        raise RuntimeError(f"release tag {tag} does not match game version v{game_version}")

    r.RESULTS["game_version"] = game_version
    r.save_results(output)
    tests = read_tests(root)
    r.RESULTS["tests"] = tests
    r.save_results(output)
    web_checks = read_web_checks(root)
    r.RESULTS["web_checks"] = web_checks
    r.save_results(output)
    android_checks = read_android_checks(root)
    r.RESULTS["android_checks"] = android_checks
    r.save_results(output)

    copy_artifacts(root, output)

    audit_desktop(output)
    audit_web(root, output)
    audit_android(root, output, android_checks)

    smoke_home = output / "smoke-home"
    smoke_home.mkdir(exist_ok=True)
    r.run(
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

    write_readme(output, commit, godot_version, game_version)
    write_build_report(output, tests, web_checks, android_checks, commit, game_version, godot_version)
    legal = r.legal_entries(output)
    stored = {".exe", ".x86_64", ".pck", ".zip", ".png", ".jpg", ".jpeg", ".ogg", ".ttf", ".woff2"}
    common_required = (
        "RELEASE-README.md",
        "CI-BUILD-REPORT.md",
        "README.md",
        "LICENSE",
        "NOTICE",
        "LICENSE-CC-BY-4.0.txt",
    )
    r.write_zip(
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
    r.write_zip(
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
    build_web_zip(root, output, legal)

    entries, missing = r.source_entries()
    if missing:
        raise RuntimeError(f"tracked source files missing from working tree: {missing}")
    r.write_zip(
        output / "watch-yongchang-source.zip",
        entries,
        stored,
        output,
        source_package=True,
        required=(
            "watch-yongchang/README.md",
            "watch-yongchang/LICENSE",
            "watch-yongchang/dora/init.lua",
        ),
    )
    write_build_report(output, tests, web_checks, android_checks, commit, game_version, godot_version)

    r.RESULTS["processes_after_cleanup"] = r.process_snapshot()
    r.RESULTS["finished_at"] = r.now()
    r.save_results(output)
    if r.RESULTS["processes_after_cleanup"]:
        raise RuntimeError(
            f"engine processes remain after release build: {r.RESULTS['processes_after_cleanup']}"
        )

    artifact_names = [
        "watch-yongchang-linux.x86_64",
        "watch-yongchang-linux.pck",
        "watch-yongchang-windows.exe",
        "watch-yongchang-windows.pck",
        "watch-yongchang-macos.zip",
        "watch-yongchang-android.apk",
        "watch-yongchang-web.zip",
        "watch-yongchang-linux.zip",
        "watch-yongchang-windows.zip",
        "watch-yongchang-source.zip",
        "RELEASE-README.md",
        "CI-BUILD-REPORT.md",
    ]
    records = [r.artifact_record(output / name, "release") for name in artifact_names]
    manifest = {
        "schema_version": 4,
        "project": "守望 · 永昌 / Watch of Yongchang",
        "generated_at": r.RESULTS["finished_at"],
        "commit": commit,
        "game_version": game_version,
        "godot_version": godot_version,
        "tests": tests,
        "web_checks": web_checks,
        "android_checks": android_checks,
        "artifacts": records,
        "web": {
            "platform": "EdgeOne Makers",
            "project": "shouwang",
            "url": "https://2026shouwang.needhelp.icu",
            "threads": False,
            "cross_origin_isolation_required": False,
        },
        "checks": r.RESULTS["checks"],
        "processes_after_cleanup": r.RESULTS["processes_after_cleanup"],
        "pending_external_acceptance": [
            "native Windows release execution",
            "macOS hardware run",
            "EdgeOne custom-domain DNS and certificate propagation",
            "AtomGit mirror",
            "Bilibili upload with competition tag",
            "原子派 publication and 20 likes",
            "competition submission",
            "competition peer review",
        ],
    }
    manifest_path = output / "release-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    checksum_names = artifact_names + ["release-manifest.json", "release-results.json"]
    sums = [f"{r.sha256(output / name)}  {name}" for name in checksum_names]
    (output / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    print(json.dumps({"manifest": str(manifest_path), "artifacts": len(records)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
