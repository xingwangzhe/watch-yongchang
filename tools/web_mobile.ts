export const MOBILE_WEB_ORIENTATION = "landscape" as const;

const style = `
<style id="mobile-orientation-style">
html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; overscroll-behavior: none; }
body, canvas { touch-action: none; }
canvas { max-width: 100vw; max-height: 100dvh; }
#mobile-orientation-gate { display: none; position: fixed; inset: 0; z-index: 2147483647; box-sizing: border-box; align-items: center; justify-content: center; flex-direction: column; gap: 1rem; padding: max(24px, env(safe-area-inset-top)) max(24px, env(safe-area-inset-right)) max(24px, env(safe-area-inset-bottom)) max(24px, env(safe-area-inset-left)); background: #081014; color: #efe1c2; font: 18px/1.6 system-ui, sans-serif; text-align: center; }
#mobile-orientation-gate button { min-height: 48px; padding: 0.7rem 1.3rem; border: 1px solid #e1b35a; border-radius: 999px; background: #241a0b; color: #efe1c2; font: inherit; touch-action: manipulation; }
@media (orientation: portrait) and (pointer: coarse) { #mobile-orientation-gate { display: flex; } }
</style>`;

const overlay = `
<div id="mobile-orientation-gate" role="status" aria-live="polite">
  <strong>请横屏游玩 / Rotate your device</strong>
  <span>点击尝试锁定横屏；若浏览器不支持，请旋转设备。</span>
  <button id="mobile-orientation-button" type="button">尝试横屏 / Try landscape</button>
</div>
<script>
(() => {
  const button = document.getElementById("mobile-orientation-button");
  if (!button) return;
  button.addEventListener("click", async () => {
    try {
      if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
        await document.documentElement.requestFullscreen();
      }
      if (screen.orientation && screen.orientation.lock) {
        await screen.orientation.lock("landscape");
      }
    } catch (_) {
      // Browsers can deny fullscreen/orientation locks; the rotate prompt remains visible.
    }
  });
})();
</script>`;

export const mobileOrientationShell = { head: style, body: overlay } as const;

export function injectMobileOrientationShell(html: string): string {
  if (html.includes('id="mobile-orientation-style"')) return html;
  const withStyle = html.replace("</head>", `${mobileOrientationShell.head}\n</head>`);
  return withStyle.replace(/<body\b[^>]*>/i, (body) => `${body}${mobileOrientationShell.body}`);
}
