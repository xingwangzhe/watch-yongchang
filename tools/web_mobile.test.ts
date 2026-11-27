import { describe, expect, test } from "bun:test";
import { injectMobileOrientationShell, MOBILE_WEB_ORIENTATION } from "./web_mobile";

describe("mobile Web shell", () => {
	test("requests portrait for installed PWA", () => {
		expect(MOBILE_WEB_ORIENTATION).toBe("portrait");
	});

	test("keeps the game canvas touch-ready without blocking portrait play", () => {
		const html = injectMobileOrientationShell("<html><head></head><body><canvas id=\"canvas\"></canvas></body></html>");
		expect(html).toContain("touch-action: none");
		expect(html).not.toContain("mobile-orientation-gate");
		expect(html).toContain("<canvas id=\"canvas\"></canvas>");
	});

	test("does not duplicate the shell if export enhancement runs twice", () => {
		const once = injectMobileOrientationShell("<html><head></head><body></body></html>");
		const twice = injectMobileOrientationShell(once);
		expect(twice).toBe(once);
		expect((twice.match(/id="mobile-orientation-style"/g) ?? []).length).toBe(1);
	});
});
