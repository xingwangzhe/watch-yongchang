# 《守望·永昌》可玩验证版（Godot 4.7.2）

> 三路暴兵对推 + 箭塔塔防 + 补给断供停火 + 文化事件，一局约 5–8 分钟。
> 由 gda CLI 0.25.0 无头创建与验证，**未使用 Godot 编辑器 GUI**。

## 快速运行

```bash
# 编辑器打开 game/ 后 F5；或命令行窗口模式运行：
/home/xingwangzhe/桌面/Godot_v4.7.2-stable_linux.x86_64 --path game
```

操作：`1/2/3` 出兵（乡勇/弓手/龙灯队，扣银）；`R` 重开。
目标：守住己方主堡（HP 1000），推掉敌方主堡；三波打完按主堡 HP 判胜。

## CLI 验证命令

```bash
cd /home/xingwangzhe/桌面/2026游戏赛事
# 1) 静态校验
gda scene validate res://scenes/main.tscn --project game --json
# 2) 启动预检
gda scene preflight res://scenes/main.tscn --project game --frames 20 --json
# 3) 自动化断言（19 项）
gda script run res://tests/verify.gd --project game --json
# 4) 实机运行观察
gda daemon start --project game --json
gda daemon wait-ready --project game --json
gda game call /root/GameState --method get_debug_snapshot --project game --json
gda logger tail --project game --json
gda diag errors --project game --json
gda daemon stop --project game --json
```

判定标准：`scene preflight started=true`、`script run exit_status=0` 且 `[SUMMARY] PASS=19 FAIL=0`、`diag errors` 为空、实机日志出现 `[TOWER] fire`、`[PROJ] hit`、`[WAVE]`、`[CULTURE]` 与 snapshot 中 `kills` 增长。

## 结构

```
game/
├── project.godot          # 工程配置：1280×720，gl_compatibility，5 个 autoload，全局主题字体=lxwk
├── themes/default.tres   # 全局默认 Theme：default_font = 霞鹜文楷（LXGW WenKai）
├── scenes/
│   ├── main.tscn          # 主场景：Lanes/Battle/Projectiles/FX/UI
│   ├── unit.tscn          # 单位模板（PathFollow2D + AnimatedSprite2D）
│   ├── projectile.tscn    # 弹道模板
│   └── tower_node.tscn    # 箭塔模板
├── scripts/
│   ├── main.gd            # 波次、出兵、胜负、HUD 桥接
│   ├── unit.gd / tower.gd / projectile.gd / hud.gd
│   └── autoload/          # EventBus/DataDB/ResourceManager/GameState/SupplySystem
├── data/                  # 由 design/data/*.csv 转出的 JSON（60 兵种/4 塔/10 建筑/6 关）
├── tests/verify.gd        # 19 项自动化断言
└── assets/                # 素材副本：3 兵种精灵、3 建筑、原创音频、霞鹜文楷字体
```

## 玩法闭环

```
准备期 12s → 波次1(6敌) → 波次2(10敌,抗倭事件) → 波次3(14敌) → 按主堡 HP 判定
玩家：1/2/3 出兵推进（银）  |  箭塔自动索敌（弹药，军械坊产出）  |  断供即停火
```

## 字体与协议

- 全工程 UI 字体统一使用 **lxwk（霞鹜文楷 / LXGW WenKai）**：`assets/fonts/LXGWWenKai-Regular.ttf`。
- 通过 `gui/theme/custom = res://themes/default.tres` 设为**全局默认字体**，HUD 另有一层显式覆盖确保生效。
- 字体许可 **SIL Open Font License 1.1**，完整协议文本：`assets/fonts/OFL.txt`（根目录 `assets/fonts/OFL.txt` 亦有一份）。原始项目 https://github.com/lxgw/LxgwWenKai 。未修改字体文件、未更改保留字体名。

## 已知限制

- 玩家单位与敌方单位共用同一碰撞/伤害链，但未做阵营间互相攻击（玩家出兵主要用于推敌堡）。
- 事件卡目前仅「抗倭」一条有日志提示，效果数值未全部接入。
- 音频/字体授权与 AI 生成声明见根目录 `AI使用与素材声明.md` 与 `素材授权清单.csv`。
- `.godot/` 为引擎缓存，已加入 `.gitignore`，不要提交。
