# 箭塔图像接入

`game/data/towers.json` 为三种正式箭塔记录 `art_source` 与 `art_cell`。
`build.py` 从 `pixel-art/renewed_composable/source/watchtowers.png` 的 2×2 图集读取
正式塔身（望楼第2格、箭楼第0格、龙首箭楼第3格），去除明示的绿色色键，按主体边界裁切，
用最近邻缩放到 168×168，输出 PNG 源图、无损 WebP 运行图及联系表。
箭塔使用的旋转连弩取自 `pixel-art/renewed_composable/source/weapon_props.png` 第 10 格（独立弩），
同样由脚本去洋红色键并输出正式 PNG/WebP；运行时按目标方向旋转贴图并保留后坐反馈。

运行以下命令重建并强制核对 Source → PNG/WebP → JSON 的映射：

```bash
python3 pixel-art/towers/build.py
python3 pixel-art/towers/test_build.py
```

正式战斗直接绘制完整生成箭塔图与独立生成弩贴图。发射方向、后坐与枪口闪光仍由
运行时反馈驱动；弩身不再使用程序化线条拼画。
