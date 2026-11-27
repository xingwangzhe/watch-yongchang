export const MOBILE_WEB_ORIENTATION = "portrait" as const;

const style = `
<style id="mobile-orientation-style">
html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; overscroll-behavior: none; }
body, canvas { touch-action: none; }
canvas { max-width: 100vw; max-height: 100dvh; }
</style>`;

export const mobileOrientationShell = { head: style, body: "" } as const;

export function injectMobileOrientationShell(html: string): string {
  if (html.includes('id="mobile-orientation-style"')) return html;
  const withStyle = html.replace("</head>", `${mobileOrientationShell.head}\n</head>`);
  return withStyle.replace(/<body\b[^>]*>/i, (body) => `${body}${mobileOrientationShell.body}`);
}
