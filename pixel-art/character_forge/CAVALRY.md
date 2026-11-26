# CharacterForge 骑兵资产

本管线用 `skills/pixel-art-studio` 的 Pillow 代码绘制方式生成未骑乘马匹和
骑手动作条带。所有 PNG 都由脚本重建，禁止手改导出文件。

## 生成

从项目根目录运行：

```bash
python3 pixel-art/character_forge/build_cavalry.py
python3 pixel-art/character_forge/test_cavalry.py
```

`build_cavalry.py` 同时通过现有 `CharacterForge.write_data()` 更新
`game/data/character_templates.json` 的骑兵元数据和统计字段。

## 规格

- 单元：128×128，透明 RGBA，最近邻像素风。
- `idle`：4 帧，6 fps；`walk`：8 帧，10 fps。
- 朝向：右向；落脚锚点 `(64, 122)`。
- 步态：`diagonal_trot`（斜对角快步）。近前腿与远后腿同相，近后腿与远前腿反相。
- 马体、头颈、尾巴和鞍桥分别起伏；骑手躯干比马背滞后一帧。
- 骑手复用现有明军/倭寇 `skin`、`outfit`、`headgear`、`backgear` 层，
  另绘坐姿躯干、缩短手臂、骑乘腿、马鞍、鞍垫、肚带和马镫。

## 配方

### 马匹

| 配方 id | 名称 | 动作条带 |
|---|---|---|
| `mount_zhaohong` | 枣红马 / Chestnut Bay | `game/assets/units/forge/cavalry/mount_zhaohong/{idle,walk}.png` |
| `mount_black` | 乌骓马 / Black Warhorse | `game/assets/units/forge/cavalry/mount_black/{idle,walk}.png` |
| `mount_grey` | 霜灰马 / Frost Grey | `game/assets/units/forge/cavalry/mount_grey/{idle,walk}.png` |

### 骑手

| 配方 id | 阵营 | 马匹 | 动作 | 条带 |
|---|---|---|---|---|
| `ming_zhaohong_lancer` | 明军 | 枣红马 | 骑枪近战 / `lance_charge` | `game/assets/units/forge/cavalry/ming_zhaohong_lancer/{idle,walk}.png` |
| `ming_black_bow` | 明军 | 乌骓马 | 骑弓远程 / `mounted_bow` | `game/assets/units/forge/cavalry/ming_black_bow/{idle,walk}.png` |
| `wokou_grey_saber` | 倭寇 | 霜灰马 | 骑刀近战 / `saber_cut` | `game/assets/units/forge/cavalry/wokou_grey_saber/{idle,walk}.png` |
| `wokou_black_bow` | 倭寇 | 乌骓马 | 骑弓远程 / `mounted_bow` | `game/assets/units/forge/cavalry/wokou_black_bow/{idle,walk}.png` |
| `wokou_black_lancer` | 倭寇精英 | 乌骓马 | 骑枪近战 / `lance_charge` | `game/assets/units/forge/cavalry/wokou_black_lancer/{idle,walk}.png` |
| `wokou_oni_lancer` | 倭寇 Boss | 乌骓马 | 鬼面骑枪近战 / `lance_charge` | `game/assets/units/forge/cavalry/wokou_oni_lancer/{idle,walk}.png` |

## 元数据

`character_templates.json` 新增：

- `mounts`：3 种马及各自色板。
- `cavalry_actions`：3 种骑手动作及武器层映射。
- `mount_recipes`、`cavalry_recipes`：可运行配方和条带路径。
- `cavalry_gait`：4/8 帧、6/10 fps、斜对角步态说明。
- `cavalry_compatibility`：马匹/骑手阵营兼容和代表性资产。
- `cavalry_rider_style_counts`、`cavalry_faction_combination_counts`、
  `cavalry_combination_count`：样式组合统计。

当前样式组合：

```text
明军  = 3 mounts × 3 actions × 4 skins × 8 outfits × 8 headgear × 4 backgear = 9,216
倭寇  = 3 mounts × 3 actions × 4 skins × 10 outfits × 8 headgear × 2 backgear = 5,760
通用  = 3 mounts × 3 actions × 4 skins × 2 outfits × 2 headgear × 1 backgear = 144
合计  = 15,120
```

该数字是样式组合容量，不是掉落权重或运行时实际生成分布。旧步兵
`combination_count = 74,752` 保持不变。

运行时由 `RuntimeLoadout` 生成独立配装快照，`Battlefield` 每个敌兵只抽样一次。
骑兵近战在 `wokou_grey_saber` / `wokou_black_lancer` / `wokou_oni_lancer` 之间
按角色档位选择，骑兵远程统一使用 `wokou_black_bow`；调色、纹章与武器皮肤作为
实例视觉键参与批处理缓存。佣兵 `yishi_rider` 与 `yishi_horse_archer` 分别读取
明军骑枪与骑弓条带。

## 预览

以下预览由 `build_cavalry.py` 自动生成：

- `cavalry_roster.png`：全部马匹与骑手的 4 idle + 8 walk。
- `cavalry_gait_sheet.png`：三种马的 8 帧步态大图。
- `cavalry_detail_sheet.png`：4× 近检。
- `cavalry_layer_breakdown.png`：马、缰绳、骑手、合成和剪影分层。

## 范围

马匹与骑手条带属于 `game/assets/units/forge/cavalry/` 正式运行时资产；
战斗、佣兵与图鉴均只引用该目录，不引用旧兵种目录。新增变体仍须由
`build_cavalry.py` 重建并同步授权清单、`credits.json` 与设计文档。
