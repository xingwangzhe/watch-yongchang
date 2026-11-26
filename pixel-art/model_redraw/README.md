# 模型生成像素图与组合素材

本目录保存 OpenAI ImageGen 生成的完整角色参考、模块类别草图与对应切片/QA流程。逐图来源、分格和状态见 `manifest.json`。

## 组合原则

- 步兵身体、步兵上身动作、骑乘坐姿、独立马匹、武器、建筑分别生成。
- `mounted_riders_reference.png` 是穿戴骑手参考，严禁切入组合素材。
- `architecture_atlas_model_v1_source.png` 是已接入地图的建筑图集来源；运行时格图由
  `qa_architecture_atlas_v1.py` 从 8×6 源图裁切、透明阈值化并最近邻缩放到 32×32，
  写入 `game/assets/tiles/yongchang/architecture_atlas_ai_v1.png`。
- `horse_motion_v4.png` 仅提供 3 行 × 8 帧的独立马匹行走底图，由
  `pixel-art/character_forge/build_cavalry.py` 按 `cavalry_data.py` 的毛色行号
  接入正式骑兵烘焙；程序化缰具、鞍具和 CharacterForge 骑手配方保持独立层。
- `full_sprite_concepts_v2.png` 先定下明军步兵、倭寇步兵、令旗手和骑兵的完整造型；
  `modular_parts_v2.png` 再按头部、躯干、腿部、武器和旗帜拆大类。模块草图虽透明、
  边界清楚，但动作姿势与握点尚未匹配 CharacterForge 骨架，暂不进入正式拼装。
- `walk_base_v4_source.png` 是 4×2 的 8 帧独立行走身体底图，不含服装、武器、盾牌或坐骑。切片时先清除低透明度边缘，再按比例缩放；与独立阵营服装及 CharacterForge 配方装备组合。旧王陆完整角色条带仅保留为研究参考，正式角色全部按可组合图层烘焙。

## 切分

```bash
python3 pixel-art/model_redraw/slice_generated.py weapons_implements.png --output /tmp/weapon-cells
python3 pixel-art/model_redraw/slice_generated.py fort_buildings_tiles.png --output /tmp/fort-cells
```

一般切片脚本只按网格裁格。建筑图集使用 `qa_architecture_atlas_v1.py`，其输出另做
alpha 阈值、最近邻缩放、3×3重复检查；脚本不绘制或补画像素。

新生成的行走、骑乘和攻击动作大图，可先用 `slice_modular_atlas.py` 做批量裁格与帧审计：

```bash
python3 pixel-art/model_redraw/slice_modular_atlas.py ground_body_actions_v3.png \
  --output /tmp/yongchang-slice/body --cell-size 128x128 --alpha-threshold 128 \
  --frame-rows --contact /tmp/yongchang-slice/body.png \
  --report /tmp/yongchang-slice/body.json
```

切片表按 manifest 网格编号。报告会记录逐格 alpha 覆盖、内容边界和同一动作行相邻帧差异；
接触表使用棋盘底显示真实透明度。它不会把 RGB 棋盘格或色键抠成透明，也不会补画、修帧或
移动部件锚点；这些质量不合格的图仍须留在研究状态。先看接触表，再决定是否进入角色烘焙器。

CharacterForge 图层试拼使用 `prototype_characterforge_v3.py`。该原型分别合成明军与倭寇的
8 帧行走层、5×6 帧动作层和马匹/鞍具/骑手层。动作服装按原动作行列一一对应，保留 128px
格内位置；行走衣装按 74×75px 缩放、底边放到 y=104，再把基础头脸裁片盖回衣装之上。骑乘层序
为马、阵营鞍具、基础骑手、阵营骑手衣装、骑手头脸。运行
`python3 pixel-art/model_redraw/prototype_characterforge_v3.py` 会在
`/tmp/yongchang-asset-qa/characterforge_v3_prototype/` 生成 PNG 和 JSON QA 报告。
原型共用基础地面身体与骑手身体，但动作服装、骑手衣装和鞍具按阵营分开。所有输出仅用于
QA；尚未接入正式图集。

## 当前接入结果

- `weapons_atlas_v5_source.png` 是 4×4 独立兵器图，色键 #ff00ff。16 个可用单件按握点
  和姿态接入 `pixel-art/character_forge/build.py`；生成的 `weapons.png` / `offhands.png`
  由 `bake_battle_sprites.py` 烘焙进正式 `game/assets/units/forge/` 条带。
- `arrow_towers_v1_source.png` 是 4×1 独立箭塔大图，色键 #00ff00。前三格分别作为望楼、
  箭楼、龙首箭楼，由 `pixel-art/towers/build.py` 透明切片与最近邻缩放到运行时尺寸；
  第四格仅做变体参考。预览在 `pixel-art/towers/preview.png`。
- `architecture_atlas_model_v1_source.png` 的 47/48 格已经接入 Yongchang 瓦片图集；
  新的 `fort_tile_parts_v2_source.png` 仍是建筑概念件，邻接和通行逻辑检查前不覆盖正式瓦片。
- `walk_base_v3_source.png`、阵营衣装、攻击动作和骑乘层已切片并做逐帧组合检查；
  它们目前留在 QA 原型，不作为正式角色条带。去色边和角色装备组合还需通过完整烘焙验收。
- Pillow只负责裁切、色键去背、最近邻缩放和拼层；新像素不通过代码绘制。

## 生成质量记录

- 步兵身体图中模型将棋盘格烘焙进 RGB，不能当透明图使用。
- 武器与独立马匹图也含棋盘格背景；部分所谓连续帧变化很弱，不能作为动画成品。
- 上身与骑手坐姿使用纯色键背景，仍需去色边和逐格轮廓校验。
- 建筑模块按现有 48 个命名格切片；墙、屋顶、门与水岸边缘须按
  `architecture_atlas_model_v1_QA.md` 中的邻接方向组合。
- 未在 `manifest.json` 标记为运行时使用的模型图仍仅供研究与预览。

## 文化锚点

方向来自项目公开文化资料：永昌堡石墙、敌台、陆水门、双渠与石桥，明代沿海卫所、抗倭乡兵，青灰砖瓦、朱红灯火与龙灯色彩。叙事不得写成汤和修筑永昌堡。

### 地面攻击动作 QA

`ground_attack_bodies_v3_source.png`、`ming_ground_attack_clothing_overlay_v1_source.png` 与 `wokou_ground_attack_clothing_overlay_v1_source.png` 均为 6×5 大图。运行 `python3 pixel-art/model_redraw/bake_ground_attack_qa.py`，会从原图执行色键切分并输出两阵营身体+衣装联系表和帧差 JSON 到 `/tmp/yongchang-ground-attack-qa/`。联系表不含武器、副手或完整装备角色。五行语义尚未完成武器动作映射，故仍是 QA 素材，不进入运行时。
