# game/ — Godot 工程

状态（2026-11-23）：基础 UI 骨架完成，M0 玩法待建。

新玩法：Vampire Survivors-like 割草生存 Roguelite，16 分钟单局。
设计源：`../design/游戏设计文档-GDD.md`。

## 已实现

- `scenes/main_menu.tscn`：夜城望楼主菜单，开始/继续游戏、设置、关于、语言、退出。
- `scenes/about.tscn`：电影滚幕式关于页；自动上滚，滚轮/方向键接管，
  专用 BGM；来源链接直接内嵌在致谢、音乐、字体、工具与文化参考条目。
- 设置层：BGM/音效滑杆、全屏开关、中英语言选择，改动即保存。
- `scripts/autoload/`：`GameSettings`、`Locale`、`SaveSystem`、`AudioBus`。
- 自动存档：菜单、设置变化、开局、退出与每 20 秒写入 `user://savegame.json`。
- 双语：`data/i18n/zh.json` 与 `en.json`，切换后即时刷新界面。
- BGM：`assets/audio/bgm_watch.ogg`，**Samurai Nights · majadroid · CC-BY 3.0**。
- 关于页 BGM：`assets/audio/bgm_about.ogg`，
  **Views From Atop the Jade Kings Throne · Hitctrl · CC-BY 3.0**。
- `scenes/run.tscn`：开局占位场景，显示第一夜并验证自动存档/返回链路。

## 运行

```bash
"$GDA_GODOT" --path game
```

主菜单键盘操作：`↑↓` 选择，`Enter` 确认，`Esc` 关闭设置。

## 测试

- GUT 9.7.1（MIT），位于 `addons/gut/`，固定对应 Godot 4.7.x。
- 运行全部单元测试：
  `"$GDA_GODOT" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- 当前覆盖：工程基线、双语表一致性、存档往返、自动存档、设置持久化、
  BGM 循环与音量、菜单构建/设置层、语言热切换、关于页自动滚幕/滚轮接管/来源链接。
- 数据与平衡模拟走 Bun + TypeScript，不启动引擎。

## 截图

- `../docs/screenshots/ui_2026-11-23/main_menu_zh.png`
- `../docs/screenshots/ui_2026-11-23/settings_zh.png`
- `../docs/screenshots/ui_2026-11-23/about_top_zh.png`
- `../docs/screenshots/ui_2026-11-23/about_sources_zh.png`
- `../docs/screenshots/ui_2026-11-23/about_music_zh.png`
- `../docs/screenshots/ui_2026-11-23/about_takeover_zh.png`
- `../docs/screenshots/ui_2026-11-23/main_menu_en.png`
- `../docs/screenshots/ui_2026-11-23/run_placeholder_zh.png`

## 资产

- `assets/units/`：11 组 64×64 兵种序列帧（可复用为角色/敌人）。
- `assets/tiles/dcss/`：CC0 地形图块 106 张。
- `assets/ui/`、`assets/audio/`、`assets/fonts/`：已登记素材。
- BGM 与字体署名数据在 `data/credits.json`。
- 文化背景与赛事创作方向来源：
  [2026 OSGJ 开源游戏开发大赛官网](https://2026gamejam.osgame.org/)。
- 新像素素材用 `skills/pixel-art-studio/` 生成，源文件放 `../pixel-art/<slug>/build.py`。

## 下一步（M0）

1. 玩家八向移动 + 1 把腰刀自动攻击 + 1 种斥候 + 经验/升级。
2. 主菜单接入真实开局参数，替换 `run.tscn` 占位场景。
3. 补战斗 HUD、暂停与升级三选一。
