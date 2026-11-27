# 质量守卫

此项目用三类独立证据守护玩法、性能与视觉交付。它借鉴 [Google《Software Engineering at Google》第 6 章](https://abseil.io/resources/swe-book/html/ch06.html)的质量、延迟、容量三角权衡；三个指标必须一起观察，不能把“质量”单独最大化后忽略响应时间和运行成本。

| 维度 | 项目指标 | 守卫 |
|---|---|---|
| 质量 | GUT 玩法与场景测试；TLC 有限状态模型不变量；MCP 对 GDScript、场景与资源做深度校验 | `.github/workflows/verify.yml`、`.github/workflows/quality-guards.yml` |
| 延迟 | 460 敌人时世界逻辑平均更新低于 16.67 ms；三张地图流场切片 p95 低于 1 ms | `tools/perf_quality_guard.ts`，由 `quality-guards.yml` 执行 |
| 容量 | 固定维持 460 个活动敌人的压力场景，验证规模增长时更新成本仍在帧预算内 | `game/tests/perf/stress_scene.tscn` 与 `quality-guards.yml` |

`quality-guards.yml` 可由 `verify.yml` 和 `release.yml` 调用；任何一个模型、视觉结构或性能守卫失败都会阻断 GUT、平台检查与发布步骤。自动视觉检查会保存审查图集供人工查看，不能代替人眼审美验收。

## 形式化模型边界

`game/formal/NightWatch.tla` 把生命归零、灯油摸黑、经验加成、升级上限和五色龙鳞清场写成有限状态模型。TLC 会穷举配置域中的可达状态并检查安全不变量；它证明的是该抽象模型，不是对整个 GDScript 程序的机器证明。GUT 负责把模型所表达的行为连到运行时代码。更改玩法规则时，应同时修改规格、模型配置和对应的 GUT 行为测试。

## 视觉守卫

角色与地图改动须从完整人物/地图图集生成，保留同一帧尺寸、角色重心和调色板层级。CI 保存图集审查产物；人眼复核静态首帧、整段移动、攻击动作、敌我辨识和各地图岸线/建筑接缝。自动检查只能发现结构与回归，不能单独判定审美。
