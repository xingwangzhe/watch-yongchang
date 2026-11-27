#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

import package_release as release


GUT_LOG = """\
Scripts 221
Tests 221
Passing Tests 221
Asserts 75850
All tests passed!
"""

ANDROID_LOG = f"""\
package=fun.xingwangzhe.watchyongchang
abis=arm64-v8a,armeabi-v7a
min_sdk=24
target_sdk=36
version={release.r.project_version()}
gamepad_actions=move:left_stick,dpad;attack:A;dash:B;interact:X;codex:Y;auto_attack:Back
gamepad_tests=GUT:test_android_gamepad.gd
signature=verified_release_key
signature_fingerprint_match=true
signature_certificate_sha256=FE2679C0E430FA76A1CBEE6C2D3C07BE4E2954E531F565028B06B47BEB20FD7E
ANDROID_BUILD_CHECKS_OK
"""

SIGNATURE_LOG = """\
Verifies
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
Signer #1 certificate SHA-256 digest: fe:26:79:c0:e4:30:fa:76:a1:cb:ee:6c:2d:3c:07:be:4e:29:54:e5:31:f5:65:02:8b:06:b4:7b:eb:20:fd:7e
"""


class PackageReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write(self, relative: str, text: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def test_single_gut_log_replaces_platform_logs(self) -> None:
        self.write("gut/gut.log", GUT_LOG)

        summary = release.read_tests(self.root)

        self.assertTrue(summary["passed"])
        self.assertEqual(summary["tests"], 221)
        self.assertEqual(summary["asserts"], 75850)
        self.assertEqual(summary["log"], "gut/gut.log")
        self.assertNotIn("platforms", summary)

    def test_missing_platform_gut_logs_are_irrelevant(self) -> None:
        self.write("gut/gut.log", GUT_LOG)
        self.assertFalse((self.root / "linux" / "gut.log").exists())
        self.assertFalse((self.root / "windows" / "gut.log").exists())
        self.assertFalse((self.root / "macos" / "gut.log").exists())

        summary = release.read_tests(self.root)

        self.assertTrue(summary["passed"])

    def test_web_checks_require_marker(self) -> None:
        self.write("web/build-check.log", "threads=false\nWEB_BUILD_CHECKS_OK\n")

        checks = release.read_web_checks(self.root)

        self.assertTrue(checks["passed"])
        self.assertEqual(checks["log"], "web/build-check.log")

    def test_web_checks_reject_incomplete_log(self) -> None:
        self.write("web/build-check.log", "threads=false\n")

        with self.assertRaises(RuntimeError):
            release.read_web_checks(self.root)

    def test_android_checks_require_signed_dual_abi_apk_and_gamepad_test(self) -> None:
        self.write("android/build-check.log", ANDROID_LOG)
        self.write("android/signature-check.log", SIGNATURE_LOG)

        checks = release.read_android_checks(self.root)

        self.assertTrue(checks["passed"])
        self.assertEqual(checks["abis"], ["arm64-v8a", "armeabi-v7a"])
        self.assertEqual(checks["gamepad_test"], "GUT:test_android_gamepad.gd")
        self.assertEqual(
            checks["certificate_sha256"],
            "FE2679C0E430FA76A1CBEE6C2D3C07BE4E2954E531F565028B06B47BEB20FD7E",
        )

    def test_android_checks_fail_when_v3_signature_is_missing(self) -> None:
        self.write("android/build-check.log", ANDROID_LOG)
        self.write(
            "android/signature-check.log",
            "Verified using v2 scheme (APK Signature Scheme v2): true\n",
        )

        with self.assertRaises(RuntimeError):
            release.read_android_checks(self.root)

    def test_android_release_checks_reject_debug_keys_or_mismatched_fingerprints(self) -> None:
        self.write("android/build-check.log", ANDROID_LOG.replace("verified_release_key", "verified_debug_key"))
        self.write("android/signature-check.log", SIGNATURE_LOG)
        with self.assertRaises(RuntimeError):
            release.read_android_checks(self.root)

        self.write("android/build-check.log", ANDROID_LOG)
        self.write(
            "android/signature-check.log",
            SIGNATURE_LOG.replace("fe:26:79", "de:26:79"),
        )
        with self.assertRaises(RuntimeError):
            release.read_android_checks(self.root)

        self.write(
            "android/build-check.log",
            ANDROID_LOG.replace("signature_fingerprint_match=true", "signature_fingerprint_match=false"),
        )
        with self.assertRaises(RuntimeError):
            release.read_android_checks(self.root)

    def test_android_apk_audit_checks_manifest_and_both_abis(self) -> None:
        import zipfile

        apk = self.root / "watch-yongchang-android.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"manifest")
            archive.writestr("lib/arm64-v8a/libgodot_android.so", b"arm64")
            archive.writestr("lib/armeabi-v7a/libgodot_android.so", b"arm32")
        checks = {
            "abis": ["arm64-v8a", "armeabi-v7a"],
            "min_sdk": 24,
            "target_sdk": 36,
            "signature_schemes": ["v2", "v3"],
            "signature_type": "release",
            "signature_fingerprint_match": True,
            "certificate_sha256": "FE2679C0E430FA76A1CBEE6C2D3C07BE4E2954E531F565028B06B47BEB20FD7E",
            "gamepad_test": "GUT:test_android_gamepad.gd",
        }
        original_checks = release.r.RESULTS["checks"]
        release.r.RESULTS["checks"] = {}
        try:
            release.audit_android(self.root, self.root, checks)
        finally:
            release.r.RESULTS["checks"] = original_checks

    def test_build_report_uses_single_gate_summary(self) -> None:
        self.write("gut/gut.log", GUT_LOG)
        self.write("web/build-check.log", "WEB_BUILD_CHECKS_OK\n")
        self.write("android/build-check.log", ANDROID_LOG)
        self.write("android/signature-check.log", SIGNATURE_LOG)
        checks = release.read_web_checks(self.root)
        original_checks = release.r.RESULTS["checks"]
        release.r.RESULTS["checks"] = {"web-static": {"passed": True}}
        try:
            release.write_build_report(
                self.root,
                release.read_tests(self.root),
                checks,
                release.read_android_checks(self.root),
                "abc123",
                "1.2.0",
                "4.7.2-stable",
            )
        finally:
            release.r.RESULTS["checks"] = original_checks

        report = (self.root / "CI-BUILD-REPORT.md").read_text(encoding="utf-8")
        self.assertIn("GUT 单次前置门禁", report)
        self.assertIn("Web 构建静态检查", report)
        self.assertNotIn("| linux |", report)

    def test_missing_gut_log_fails_closed(self) -> None:
        with self.assertRaises(RuntimeError):
            release.read_tests(self.root)


if __name__ == "__main__":
    unittest.main()
