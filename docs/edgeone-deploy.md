# EdgeOne Makers Web 部署

## 产物策略

Godot Web 导出预设为 `Web`，输出目录 `game/build/web/`。运行时固定为单线程：

- `variant/thread_support=false`
- `progressive_web_app/ensure_cross_origin_isolation_headers=false`

因此 EdgeOne 静态托管不需要 COOP/COEP 响应头。Web 产物**不切分 wasm、不切分 PCK、
不做预压缩**；`index.wasm` 与 `index.pck` 原样上传，由 EdgeOne 平台负责传输压缩。

EdgeOne 单个存储文件上限为 25 MiB。普通 Godot Web 模板的 `index.wasm` 约 39.5 MB，
超过上限；本项目用 Emscripten 官方 SCons 参数裁剪运行时，并用官方 Binaryen
`wasm-opt -Oz` 二次优化。当前 `index.wasm` 为 25,781,160 B（约 24.59 MiB），
`index.pck` 为 18,333,032 B（约 17.48 MiB），距 25 MiB 上限约 423 KiB；
CI 会硬断言 wasm 与 PCK 均小于 25 MiB。

## 自定义 Web 引擎

构建逻辑在 `.github/actions/build-web-engine/action.yml`，只调用 Godot 官方构建链：

- Godot 源码 tag 取自 `game/.godot-version`；
- Emscripten SDK 固定 `4.0.20`；Godot 4.7.2 要求 `>=4.0.0`，其官方 Web
  workflow 固定 `4.0.11`，本项目采用同一 4.0 稳定线的新补丁版本；
- 编译完成的模板按 Godot / Emscripten / SCons / Action 版本缓存；命中后跳过整棵
  Godot 源码编译，仍会校验 ZIP 与 wasm 大小；
- SCons `production=yes lto=thin optimize=size debug_symbols=no use_closure_compiler=yes`；
- `threads=no arch=wasm32`，关闭物理、导航、XR、网络、ZIP、视频等未使用模块；
- 保留最小 3D mesh 支持（`disable_3d=no`），因为战斗背景使用 `QuadMesh`；
- 保留 WebP、FreeType、WOFF2、OGG/Vorbis、SVG、文本服务等运行时必需模块；
  Godot 的无损纹理 `.ctex` 内含 WebP 数据，关闭 WebP 会导致所有导入纹理解码失败；
- 构建后执行 `wasm-opt -Oz --all-features --strip-debug --strip-producers`；
- 打包为 `web_nothreads_release.zip` 并断言 wasm 小于 25 MiB。

不使用自写 wasm 分片器、浏览器端拼接 loader 或预压缩脚本。

## GitHub Actions

工作流使用仓库 Secret：

```text
EDGEONE_API_TOKEN
```

获取方式：

1. 打开 EdgeOne Makers 控制台，进入项目 `shouwang` 的工作空间；
2. 切换到「设置」页的「API Token」Tab；
3. 点击「创建 API Token」，填写描述 `watch-yongchang GitHub Actions`，选择 90 天有效期；
4. 复制 Token，在 GitHub 仓库 `Settings -> Secrets and variables -> Actions`
   新建 `EDGEONE_API_TOKEN`，不要把 Token 写入仓库、日志或文档。

当前仓库已在 2026-11-25 配置 `EDGEONE_API_TOKEN`。除非轮换凭据，不要重复创建
短期 Token。需要自助获取时，上述控制台路径仍适用。GitHub Actions 日志只显示
脱敏后的 Secret 占位符；不要把 CLI 返回的带 `eo_token` 预览地址写入仓库或文档，
生产入口统一使用自定义域名。

EdgeOne 官方 GitHub Actions 教程：
<https://pages.edgeone.ai/zh/document/use-github-actions>。
教程中的 CLI 示例按 EdgeOne Pages 编写；本项目使用 EdgeOne Makers，因此部署命令为
`edgeone makers deploy`，Secret 名与 `-t` 传参方式保持一致。

`main` 分支推送与手工触发会构建 Web 并部署到：

```text
项目名：shouwang
部署区域：global
在线域名：https://2026shouwang.needhelp.icu
```

部署命令等价于：

```bash
bunx -y edgeone@1.7.7 makers deploy game/build/web \
  -n shouwang \
  -t "$EDGEONE_API_TOKEN" \
  --area global \
  --skip-ai-gateway-sync \
  --json
```

标签发布工作流按 Linux、Windows、macOS、Web 四个平台并行构建；Web 汇总产物验证通过后，
同样部署到该项目。GitHub Release 中的 Web ZIP 是未压缩原始静态站，可直接用于普通
静态服务器。

## 自定义域名

1. 在 EdgeOne Makers 项目 `shouwang` 中添加自定义域名
   `2026shouwang.needhelp.icu`。
2. 读取 EdgeOne 给出的 CNAME 目标。
3. 在 `needhelp.icu` 的 DNSPod / 腾讯云 DNS 控制台添加：
   - 主机记录：`2026shouwang`
   - 记录类型：`CNAME`
   - 记录值：`2026shouwang.needhelp.icu.pages.dnsoe6.com`
   - TTL：600 秒或控制台允许的默认值
4. 等待 CNAME 生效后，在 EdgeOne 申请自动免费 SSL 证书。
5. 验证 HTTP 跳转、HTTPS 证书链、游戏资源与浏览器控制台。

免费证书由 EdgeOne 自动申请、部署和续期；CNAME 未指向 EdgeOne 时自动验证不会完成。

## 已验收状态（2026-11-25）

- 项目：`shouwang`，Project ID `makers-hmgmargzbiuc`，Zone ID `zone-3kfm4dogb99e`。
- 已核验 CI 部署：`Web build and EdgeOne deploy` 成功，Deployment ID
  `dp0x63yipejk`；对应四平台全绿 run
  <https://github.com/xingwangzhe/watch-yongchang/actions/runs/45594130561>。
  原始目录直传，不再使用 `web-edgeone` 分片目录，也不再有
  `edgeone-manifest.json` 或 `*.part*` 文件。
- CNAME：`2026shouwang.needhelp.icu -> 2026shouwang.needhelp.icu.pages.dnsoe6.com`，
  TTL 600，DNSPod 记录 ID `2459497778`。
- HTTPS：免费自动证书已签发，`CN=2026shouwang.needhelp.icu`，签发机构
  TrustAsia DV TLS RSA CA 2025，有效期至 2027-02-22。
- 域名控制台显示「已生效 / 已部署 / 生产」。
- 线上检查：`/`、`/index.wasm`、`/index.pck` 均返回 200；wasm 25,781,160 B，
  PCK 18,333,032 B。
- 浏览器实测：主菜单、1386 汤和序章、王陆选择页、正篇战斗均正常渲染；
  生产环境控制台无 error / warning。
