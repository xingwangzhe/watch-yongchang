import { describe, expect, test } from "bun:test";
import { injectMobileOrientationShell, MOBILE_WEB_ORIENTATION } from "./web_mobile";

describe("mobile Web shell", () => {
	test("requests landscape for installed PWA", () => {
		expect(MOBILE_WEB_ORIENTATION).toBe("landscape");
	});

	test("shows a safe-area-aware rotate gate only on coarse-pointer portrait screens", () => {
		const html = injectMobileOrientationShell("<html><head></head><body><canvas id=\"canvas\"></canvas></body></html>");
		expect(html).toContain("@media (orientation: portrait) and (pointer: coarse)");
		expect(html).toContain("env(safe-area-inset-left)");
		expect(html).toContain("screen.orientation.lock(\"landscape\")");
		expect(html).toContain("旋转设备");
		expect(html).toContain("<canvas id=\"canvas\"></canvas>");
	});

	test("does not duplicate the shell if export enhancement runs twice", () => {
		const once = injectMobileOrientationShell("<html><head></head><body></body></html>");
		const twice = injectMobileOrientationShell(once);
		expect(twice).toBe(once);
		expect((twice.match(/id="mobile-orientation-gate"/g) ?? []).length).toBe(1);
		expect((twice.match(/id="mobile-orientation-style"/g) ?? []).length).toBe(1);
	});
});
