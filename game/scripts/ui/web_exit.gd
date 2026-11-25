extends RefCounted

const CLOSE_WINDOW_SCRIPT := """
(() => {
	try { window.close(); } catch (error) {}
	try {
		if (window.opener && !window.opener.closed) {
			window.opener.focus();
		}
	} catch (error) {}
	return true;
})();
"""

const RELOAD_PAGE_SCRIPT := "window.location.reload();"


static func is_web_platform(override: int = -1) -> bool:
	if override >= 0:
		return override == 1
	return OS.has_feature("web")


static func request_close() -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval(CLOSE_WINDOW_SCRIPT, true)
	return true


static func reload_page() -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval(RELOAD_PAGE_SCRIPT, true)
	return true
