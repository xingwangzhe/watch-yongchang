# Character reference notes

本目录的最终像素图由 `build.py` 自行绘制。以下第三方素材只用于观察比例、关节连接和动作节奏，
没有复制、描摹或打包进成品。

## 人体与动作

### LPC Character Bases

- 作者：BenCreating、bluecarrot16 等
- 来源：https://opengameart.org/content/lpc-character-bases
- 许可：CC-BY-SA 3.0 / GPL 3.0（仅参考，未采用其素材）
- 观察结论：
  - 正面待机时肩、肘、腕形成接近连续的轮廓，肘部只靠 1px 折痕和明暗转折，不画关节球。
  - 大腿从髋部收向膝，小腿再收向踝；脚掌宽度明显小于大腿。
  - 行走关键帧为 contact-passing-contact-passing，手臂和腿反向摆动。
  - 突刺由身体前倾和脚步完成，武器轴线保持稳定；挥砍只在命中帧加少量残影。
- 采用方式：只把这些结构规律转写为本项目 128×128 模板的骨架比例和像素折痕。

### Free CC0 Modular Animated Vector Characters 2D

- 作者：RGS_Dev
- 来源：https://opengameart.org/content/free-cc0-modular-animated-vector-characters-2d
- 许可：CC0 1.0
- 观察结论：
  - 分层顺序应为后披挂、身体、服装、头饰、武器；手和脚必须有独立锚点。
  - 模块化角色需要固定脚底基准和手部握点，否则换装后会出现浮手、浮脚。
- 采用方式：参考其“身体部件分离但共享动作时间轴”的结构；未直接使用其 PNG。

### Kenney Modular Characters

- 来源：https://kenney.nl/assets/modular-characters
- 许可：CC0 1.0
- 结论：结构清晰，但形体偏扁平，不能满足本项目对肩肘髋膝连续性的要求，未采用。

## 本项目约束

- **阵营隔离**：明军配方只允许 `ming + neutral`，倭寇只允许 `wokou + neutral`，
  通用配方只允许 `neutral`；任何 `ming + wokou` 混装都视为非法。随机生成默认走明军，
  但必须显式指定 `ming` / `wokou` / `neutral`，不得退回混合池。
- 明军抗倭专属：狼筅、戚家刀、藤牌、镋钯、戚家军鸳鸯阵甲；明军铁盔、红披风、
  令旗等明军识别件同属 `ming`，不得出现在倭寇身上。
- 倭寇专属：倭刀、胴丸、腹卷、阵笠、鬼面、铁兜等 `wokou` 识别件，不得出现在明军
  或主角身上。通用腰刀、长枪、弓、弩、手铳、通用皮札背心、布头巾等 `neutral`
  装备可供双方自由组合，但不会改变配方阵营。
- 运行时的 `CharacterForge.set_recipe()` 会校验服装、头饰、背挂、主手与副手的
  `faction`；非法混装会被拒绝并保留上一条合法配方。
- 四肢必须由同一套骨架端点驱动，禁止用互不相连的贴片拼肢体。
- 双手与远程武器（枪、戟、斧、钺、叉、弓、弩、手铳）双臂固定在躯干前层，保证
  挥动与持握可读；单手武器远臂在非交叠时置于后层，交叠时只把前臂和手叠回前景。
- 肩、髋根点与躯干共享同一纵向骨骼位置；肘、膝只加 1px 折痕和明暗，不画深色关节球。
- 脚位必须在腿长可达范围内，构建脚本对臂长和腿长都做硬校验，禁止 IK 静默拉长。
- 图层之间只允许遮挡，不允许因锚点不一致产生 1px 以上缝隙。
- 副手是独立层：通用盾、藤牌、双刀、双钩都按主手姿态时间轴渲染，避免副手漂移；
  两件副手盾在造型上必须可区分（通用盾为红面铁盾，藤牌为黄褐编织藤盾）。
- 每次修改后重新生成图集，并查看 `body_pose_sheet.png`、`joint_contact_sheet.png`、
  `random_combo_sheet.png` 和 `dual_combo_sheet.png`；弓姿改动还必须查看
  `bow_combo_sheet.png`，确认持弓手在箭向一侧、拉弦手靠近身体；阵营或专属装备改动
  还必须查看 `faction_combo_sheet.png`，逐行确认明军、倭寇、通用三段没有混装。

## 下载与使用边界

参考包只下载到 `generated/character_candidates/`，该目录已在 `.gitignore` 排除：

- LPC Character Bases 压缩包与头部底座预览。
- RGS_Dev CC0 modular vector character 压缩包、许可和预览 GIF。
- Kenney Modular Characters 页面存档。

没有把第三方 PNG、GIF、SVG、ZIP 或描摹结果放进 `game/assets/`。最终图集由
`build.py` 用固定调色板、固定骨架和固定时间轴重新绘制；参考素材只影响比例与动作判断。
