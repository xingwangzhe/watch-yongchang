# 第三方 UI 装饰素材许可清单（TASL）

> 原始素材归档于本目录 `raw/`，转换脚本 `tools/process_thirdparty_ui.py` 输出成品至
> `game/assets/ui/`。选取标准：**可商用 + 通用化（九宫格面板/可染色符号）+ 契合当前
> 深底金描边像素风**。

## 素材清单

| 成品 | 原始文件（raw/） | Title | Author | Source | License | 修改说明 |
|---|---|---|---|---|---|---|
| `panel_gold.png`（九宫格面板） | golden-ui_ui-split_buch_CC0.png | golden-ui | buch | https://opengameart.org/content/golden-ui | **CC0** | 精灵图裁切 (176,183)-(275,215)，未改色 |
| `icon_play.png` 等 9 枚 | free-ui-asset-pack-1_ctatz_CC0.zip | Free UI Asset Pack 1 | ctatz | https://opengameart.org/content/free-ui-asset-pack-1 | **CC0** | 白色符号按亮度染色为项目金色，装进 64×64 画布 |

成品图标完整列表：`icon_play / icon_settings / icon_info / icon_close /
icon_pause / icon_volume / icon_mute / icon_check / icon_award`（对应源文件
SYMB_PLAY / SYMB_SETTINGS / SYMB_INFO / SYMB_X / SYMB_PAUSE / SYMB_VOLUME /
SYMB_MUTE / SYMB_CHECK / SYMB_AWARD）。

## 代码接入

- `game/scripts/ui/ui_kit.gd`：通用装饰套件（金框面板九宫格 StyleBoxTexture + 图标加载）。
- 已接入：主菜单按钮图标、关于面板、设置面板、HUD 事件横幅/暂停面板/结算面板。

## 许可说明

两个来源均为 **CC0 1.0（公有领域贡献）**：可商用、无需署名；本项目仍按 TASL
完整登记来源与修改，并在游戏内「关于与声明」披露。
