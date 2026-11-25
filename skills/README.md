# skills/

项目内 Agent Skills。**此目录必须保留。**

| Skill | 来源 | 许可 | 说明 |
|---|---|---|---|
| `pixel-art-studio` | https://github.com/Gamezxz/pixel-art-studio | MIT | 程序化像素美术（Pillow），角色/兵器/图块/动画/导出 |

安装日期：2026-11-23。依赖：Python 3 + Pillow 13.0.0（用户级安装）。

## 使用

```bash
# 在其自带示例目录外运行，输出落在当前目录
python3 skills/pixel-art-studio/examples/slime-build.py

# 新素材：pixel-art/<slug>/build.py
python3 pixel-art/<slug>/build.py
```

开发助手工作区（`.workbuddy/`）不随项目分发，项目只保留本目录中的可复现 skill。
