import { describe, expect, test } from "bun:test";
import {
  formatWindowsVersion,
  formatAndroidVersionCode,
  parseDotEnv,
  renderProjectMeta,
  setProjectSetting,
} from "./sync_project_env";

const sampleEnv = {
  APP_VERSION: "0.1.0",
  GODOT_VERSION: "4.7.2-stable",
  GAME_SLUG: "watch-yongchang",
  GAME_NAME_ZH: "守望·永昌",
  GAME_NAME_EN: "WATCH · YONGCHANG",
  AUTHOR: "xingwangzhe",
  AUTHOR_EMAIL: "xingwangzhe@outlook.com",
  REPO_URL: "https://github.com/xingwangzhe/watch-yongchang",
  WEB_URL: "https://2026shouwang.needhelp.icu",
  CF_PAGES_PROJECT: "shouwang",
  CF_PAGES_DOMAIN: "2026shouwang.needhelp.icu",
  APP_BUNDLE_ID: "fun.xingwangzhe.watch-yongchang",
  APP_ICON: "res://assets/ui/menu_boat.png",
  COPYRIGHT_NOTICE: "Code AGPL-3.0-or-later; original assets CC BY 4.0",
};

describe("sync_project_env", () => {
  test("parses comments, export prefixes, quotes, and escapes", () => {
    const env = parseDotEnv(`
# comment
APP_VERSION=0.1.0
export GAME_NAME_ZH="守望·永昌"
COPYRIGHT_NOTICE='Code AGPL-3.0-or-later; assets CC BY 4.0'
WEB_URL=https://example.com/game # inline comment
`);
    expect(env.APP_VERSION).toBe("0.1.0");
    expect(env.GAME_NAME_ZH).toBe("守望·永昌");
    expect(env.COPYRIGHT_NOTICE).toBe("Code AGPL-3.0-or-later; assets CC BY 4.0");
    expect(env.WEB_URL).toBe("https://example.com/game");
  });

  test("formats Windows file versions without changing the source version", () => {
    expect(formatWindowsVersion("0.1.0")).toBe("0.1.0.0");
    expect(formatWindowsVersion("12.34.56-rc.1")).toBe("12.34.56.0");
  });

  test("formats monotonic Android version codes from the source version", () => {
    expect(formatAndroidVersionCode("1.9.0")).toBe(10900);
    expect(formatAndroidVersionCode("1.10.0")).toBe(11000);
    expect(formatAndroidVersionCode("12.34.56-rc.1")).toBe(123456);
    expect(() => formatAndroidVersionCode("invalid")).toThrow();
  });

  test("renders runtime metadata from one source", () => {
    const metadata = JSON.parse(renderProjectMeta(sampleEnv));
    expect(metadata.app.version).toBe("0.1.0");
    expect(metadata.app.names.zh).toBe("守望·永昌");
    expect(metadata.author.email).toBe("xingwangzhe@outlook.com");
    expect(metadata.links.repository).toBe(sampleEnv.REPO_URL);
    expect(metadata.cloudflare_pages.project).toBe("shouwang");
  });

  test("updates or inserts a project setting inside its section", () => {
    const source = [
      "config_version=5",
      "",
      "[application]",
      'config/name="Old"',
      "",
      "[display]",
      "window/size/viewport_width=1280",
      "",
    ].join("\n");
    const inserted = setProjectSetting(
      source,
      "application",
      "config/icon",
      '"res://icon.png"',
    );
    expect(inserted).toContain('config/icon="res://icon.png"');
    expect(inserted.indexOf("config/icon")).toBeLessThan(inserted.indexOf("[display]"));
    const replaced = setProjectSetting(
      inserted,
      "application",
      "config/name",
      '"守望·永昌"',
    );
    expect(replaced).toContain('config/name="守望·永昌"');
    expect(replaced).not.toContain('config/name="Old"');
  });
});
