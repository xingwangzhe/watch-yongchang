# 模型图切片与组合检查

检查方式：读取 `manifest.json` 的格数，使用 Pillow 按格裁切、最近邻缩放及 alpha 合成；未绘制或修补任何像素。
接触表输出在 `/tmp/yongchang-asset-qa/`，不进入正式资产目录。

## alpha 与裁切检查

| 类别 | 结果 | 具体问题 |
|---|---|---|
| `ground_body_actions.png` | 有 alpha，可裁切 | cell 为 181×181；若均分，动作主体紧贴格边。第 0 行第 0 格 alpha bbox 为 `(43,16)-(179,181)`；第 0 行第 1 格为 `(13,15)-(175,181)`。部分脚贴底线或左右裁切，不适合作为统一 pivot 帧。 |
| `clothing_backgear_atlas.png` | 有 alpha，可裁切但格线不稳 | cell 约 222×222；第 0 行第 0 格衣物 bbox 覆盖左右全格并触边，衣服比例明显大于身体格。整衣轮廓不像可穿戴 overlay 的透明剪影，不支持直接叠穿。 |
| `headgear_backgear_atlas.png` | 有 alpha，可裁切但格线不稳 | 多个帽子/披挂在 cell 边缘附近。头盔是完整头盔造型，人物头部不是独立图层；其尺寸与身体图头部未匹配。 |
| `weapons_implements_v2.png` | 有 alpha，可裁切 | 每格约 280×280，武器种类/方向大体清楚，但把柄、刀尖或盾缘可能触格边。没有握持锚点，也未与角色动作对齐。 |
| `horse_walk_atlas_v2.png` | 有 alpha，可裁切 | cell 约 222×222；马匹主体侧视、帧间变化有限。马尾或腿接近格边。整体比角色图更写实，细节密度与人体不一致。 |
| `fort_arrow_tower_tiles_v2.png` | 有 alpha，可裁切 | 多行包含不同尺度的完整物体，不是统一 32×32 可平铺瓦片；望楼主体跨越大部分格，瓦片/道路混有透视和高度变化，不能直接当 TileSet。 |
| `rider_upper_body_motion.png` | 无 alpha | cyan 底烘焙进 RGB；动作行之间重复度高，不能直接切成干净透明帧。 |

旧图 `body_walk_riding_poses.png`、`weapons_implements.png`、`horses_alone.png` 与 `fort_buildings_tiles.png` 仍为不透明 RGB；棋盘格或色键背景是图像内容，不能按透明素材使用。已生成图没有可靠证据支持将它们无损自动去底。

## 试拼结果

`/tmp/yongchang-asset-qa/modular_tryon_contact.png` 展示身体、服装、头盔、刀的单独格和一次缩放叠放。

- 单项可识别：基础角色、红衣、红缨铁盔、腰刀均能看懂。
- 组合失败：衣服是正面平铺衣物，而角色是三分之四侧身完整身体；衣领/腰带/袖口没有贴合身体坐标。
- 头盔没有按人物头部投影、缩放或 pivot 绘制，叠加后悬在头顶，且颈部与衣领打架。
- 武器独立图角度偏右上，角色动作没有对应握持姿势；刀未连接手部，无法得到可信持握。
- 角色主体细小、衣物头饰独立格很大，统一等比缩放后仍无法同时匹配人物和配件。
- 不同图集使用不同视角、阴影、轮廓粗细和像素密度；跨类不一致在合成时非常明显。

## 可用性判定

- **可用于方向参考**：服装色彩、头饰/披挂种类、兵器轮廓、马匹毛色变化、望楼与堡墙造型概念。
- **仅可做单件预览**：带 alpha 的服饰、头饰、兵器、马匹格；需人工检视裁切边缘和 pivot。
- **不可直接作为组合运行素材**：身体动作与服装/头饰/兵器组合、骑手上身与马匹组合、建筑瓦片 TileSet。
- 当前角色与装备拼装不成立，关键限制是投影/尺度/锚点/握持姿势没有在同一套图集规则中共同生成，不是简单切格或 resize 能解决。

## 新版 body + clothing 复核

新版 `ground_body_actions.png` 与 `clothing_backgear_atlas.png` 已使用 Pillow 最近邻缩放和 alpha 合成制作 `/tmp/yongchang-asset-qa/body_clothing_tryon_v2.png`。新身体和新衣物笔触比上一版更接近，颜色/轮廓大方向匹配；但组合仍失败：

- 身体图包含完整角色（头、四肢、原有白色上衣和腰带），不是可供换装的裸身体/分离身体层；动作各自的姿势、大小和边界也不同。
- 衣物格是一件独立正面悬空服装，衣领开口、袖口和腰线以另一套人体位置为基准。叠加后身体头部从领口上方错位露出，原有手臂/腿被衣物遮住，成为“悬浮衣服”，无法通过统一 scale/pivot 修正。
- 衣物图没有逐动作帧：同一衣物无法随角色攻击/行走改变袖形、下摆和遮挡。也没有前后分层（袖子、裙摆、背挂）可控制层序。
- 因而不能按当前 CharacterForge schema 可靠生成 battle strips：schema 需要每个 skin/outfit/headgear/backgear 与 pose/frame 的行映射，并保证 48 帧同格、稳定 pivot、装备不盖住手部及战斗武器层次。当前衣物图是静态 8×4 展示表，无法填充 `outfit|pose` 的逐帧 atlas 行；即使复制同一衣物到 48 帧也会僵住且穿模。

结论：新版仅适合做单张概念预览；不支持 CharacterForge battle-strip 烘焙，也不建议在正式配方中引用。

## body v3 + armor + helmet + dao 试拼

`/tmp/yongchang-asset-qa/body_armor_helmet_dao_tryon_v3.png` 使用 Pillow 对以下格子裁切并合成：

- body：`ground_body_actions_v3.png`，8×6，单格 181×181；idle `(row 0,col 0)` alpha bbox `(37,16)-(161,180)`；walk 起始 `(1,0)` bbox `(72,8)-(181,176)`；attack 姿势 `(2,3)` bbox `(11,27)-(158,173)`。
- armor：指定的 `exec-d3b94e6c-f95b-4b42-8ad6-6eb0844e278e.png`，8×2，第一行第一件红札甲，单格 272×362，alpha bbox `(65,61)-(258,323)`。
- headgear：`headgear_backgear_atlas.png`，8×4，第一行第一格红缨铁盔，单格 222×222。
- weapon：`weapons_implements_v2.png`，5×4，第一行第一格刀，单格 280×280。

### 合成比例与位置（256×256 预览格，Pillow 最近邻）

为了复现预览，按 alpha bbox 裁边后使用 `thumbnail` 限制尺寸，不拉伸：

- body idle 最终约 `160×211`，左上 `(48,13)`。
- armor 最终约 `77×104`，左上 `(89,59)`；视觉覆盖胸甲区域但遮住原衣服和一部分身体。
- helmet 最终约 `38×38`，左上 `(109,16)`；在 idle 帧基本压住头顶，但不是精确贴合头部的专用遮罩。
- dao 最终约 `33×93`，左上 `(152,107)`；只是靠近右手，手掌没有真实握在刀柄上。

walk/attack 预览沿用同样的 anchor：身体格自身 bbox/pivot 会移动，例如 walk 起始人物贴右侧格边；固定锚点令头盔和 armor 相对躯干发生偏移，边缘帧有裁切风险。

### 评估

相较之前整件衣物 overlay，这一版独立胸甲可以在 idle 的单帧上形成可读的角色合成图；人物与胸甲的暗色描边、红色/棕色调及像素密度大体接近。作为“概念拼装预览”可用。仍不满足 battle strips：

- armor 图只有独立胸甲展示，不含逐帧变化，也未分别提供躯干、前后肩、裙甲/手臂遮罩；攻击动作时胸甲静态覆盖，会遮掉原手臂或跟随不了躯干角度。
- 身体本身已穿深蓝立领服，甲片叠加变成额外外挂层；视觉上能读成外穿甲，但高动作帧的装甲遮挡不可信。
- 头盔 atlas 当前格是含有头盔整体外沿/羽饰的独立帽形，叠加只能近似；没有同一身体格的专用 head anchor，动作帧对齐不稳定。
- 刀位置为视觉近似 `(152,107)`，缺少 weapon grip socket；攻击帧的手坐标变化，固定刀位会脱手。需要每帧/每动作传入握持点，或制作按动作重绘的独立 held-prop 轨道。
- 当前角色格为 `181×181`，CharacterForge 正式 battle cell 约定 `128×128`；最近邻降采样会压掉装备纹样，必须先锁定统一 crop/pivot，再测 128px 游戏尺寸。

结论：单帧可组成可读预览，整体风格和粗比例基本相容；无法据此可靠生成整套 walk/idle strips 或替换正式 CharacterForge atlas。若要接入 bake，至少需先为 48 个帧统一计算 body bbox/pivot、输出 armor/headgear 的同相位逐帧 overlay，并为武器按攻击 clip 的手部坐标设 grip anchor；本轮没有进行此接入。
