# skills/

项目内 Agent Skills。**此目录必须保留。**

| Skill | 来源 | 许可 | 说明 |
|---|---|---|---|
| `pixel-art-studio` | https://github.com/Gamezxz/pixel-art-studio | MIT | 程序化像素美术（Pillow），角色/兵器/图块/动画/导出 |
| `godot-tilemap-mastery` | https://github.com/bgrenat/godot-game-dev-studio/tree/main/skills/godot-tilemap-mastery | LGPL-3.0 | Godot 4.7 TileMapLayer、地形批处理、分层与 Y-sorting 参考 |

安装日期：2026-11-25。`godot-tilemap-mastery` 固定提交
`bcb8419fc0c0360fb9f3b0952b5fc740be6cc7c6`，只保留 `SKILL.md`、
`scripts/` 与上游 `LICENSE`，不分发仓库内其他技能或素材。

依赖：`pixel-art-studio` 使用 Python 3 + Pillow 13.0.0（用户级安装）；
`godot-tilemap-mastery` 为参考脚本，接入项目代码时须遵守 LGPL-3.0。

## 使用

```bash
# 新素材统一走项目构建脚本
python3 pixel-art/<slug>/build.py
```

上游示例和展示图不随项目分发；本目录只保留 `SKILL.md`、许可、参考文档与运行脚本。
开发助手工作区（`.workbuddy/`）不随项目分发。
