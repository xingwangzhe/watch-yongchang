# 永昌守灯 · 百度赛道轻量 H5

这是一个独立于 Godot 工程的 Canvas / JavaScript 竖屏轻量版本。Godot Web 导出的单个 WASM 与 PCK 超过百度 H5 的 10 MiB 非视频单文件限制，因此该交付不含 Godot Runtime。

## 构建

```sh
bun run baidu-h5/build.ts
```

构建产物写入 `game/build/baidu-h5/`。ZIP 解压后的根目录直接包含 `index.html` 与 `game.js`。构建脚本按百度开发者规范检查离线资源、文件名、单文件 / 总体积、禁用 API、ZIP 入口及 Deflate 压缩。

## 操作

- 手机：左下摇杆移动；攻击、冲刺、自动攻击按钮在右下区域。
- 桌面：WASD / 方向键移动，J 攻击，Space 冲刺，K 切换自动攻击。
- 守过 60 秒获胜；灯火归零失败；结果页可重开。

网页不强制旋转，优先适配 9:16。移动操作避开底部 86px 端内保留区，并避开左下 60px 返回手势带。顶部 HUD 不使用宿主 API。

## 验收边界

Bun 单元测试和本地桌面 / 移动视口浏览器测试不等于百度 App WebView 真机测试。提交前仍需在 iOS 与 Android 的百度 App 内测完整核心流程、底部遮挡、手势冲突、返回行为和启动时长。
