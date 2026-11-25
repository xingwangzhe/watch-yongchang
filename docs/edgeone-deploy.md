# EdgeOne Makers Web 部署

## 产物

Godot Web 导出预设为 `Web`，输出目录 `game/build/web/`。导出采用单线程运行时：

- `variant/thread_support=false`
- `progressive_web_app/ensure_cross_origin_isolation_headers=false`

因此 EdgeOne 静态托管无需额外配置 COOP/COEP 响应头。

EdgeOne Makers 单文件上限为 25 MiB，而当前 `index.pck`（约 43.6 MB）与
`index.wasm`（约 39.5 MB）均超过该限制。
部署前必须生成分片暂存目录：

```bash
bun run tools/prepare_edgeone_web.ts game/build/web game/build/web-edgeone
```

脚本将超限文件切成 20 MiB 分片，注入浏览器端流式拼接加载器，并生成
`edgeone-manifest.json`；同时断言暂存目录内所有文件均不超过 25 MiB。当前产物为
`index.wasm` 2 片、`index.pck` 3 片。GitHub Release 中的原始 Web ZIP 不分片，
可直接用于普通静态服务器。

## GitHub Actions

工作流使用仓库 Secret：

```text
EDGEONE_API_TOKEN
```

在 GitHub 仓库的 `Settings -> Secrets and variables -> Actions` 中添加。Token 由
EdgeOne Makers 控制台的 `API Token` 页面创建；本项目使用描述
`watch-yongchang GitHub Actions` 与 90 天有效期。Token 只写入 GitHub Secret，
不得提交到仓库、日志或聊天记录。

`main` 分支推送与手工触发会构建 Web 并部署到：

```text
项目名：shouwang
部署区域：global
在线域名：https://2026shouwang.needhelp.icu
```

部署命令等价于：

```bash
bun run tools/prepare_edgeone_web.ts game/build/web game/build/web-edgeone
bunx -y edgeone@1.7.7 makers deploy game/build/web-edgeone \
  -n shouwang \
  -t "$EDGEONE_API_TOKEN" \
  --area global \
  --skip-ai-gateway-sync \
  --json
```

EdgeOne 官方 GitHub Actions 教程：
<https://pages.edgeone.ai/zh/document/use-github-actions>。

标签发布工作流会按 Linux、Windows、macOS、Web 四个平台并行构建；Web 汇总产物验证通过后，
同样部署到该项目。

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
- 最近一次分片部署：Deployment ID `dppvs9nj2pr1`。
- CNAME：`2026shouwang.needhelp.icu -> 2026shouwang.needhelp.icu.pages.dnsoe6.com`，
  TTL 600，DNSPod 记录 ID `2459497778`。
- HTTPS：免费自动证书已签发，`CN=2026shouwang.needhelp.icu`，签发机构
  TrustAsia DV TLS RSA CA 2025，有效期至 2027-02-22。
- 浏览器实测：主菜单画布、BGM 署名、资源分片加载正常；`/edgeone-manifest.json` 可读，
  `index.wasm.part000` 与 `index.pck.part000` 均返回 200。
