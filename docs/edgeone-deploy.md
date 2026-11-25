# EdgeOne Makers Web 部署

## 产物

Godot Web 导出预设为 `Web`，输出目录 `game/build/web/`。导出采用单线程运行时：

- `variant/thread_support=false`
- `progressive_web_app/ensure_cross_origin_isolation_headers=false`

因此 EdgeOne 静态托管无需额外配置 COOP/COEP 响应头。

## GitHub Actions

工作流使用仓库 Secret：

```text
EDGEONE_API_TOKEN
```

在 GitHub 仓库的 `Settings -> Secrets and variables -> Actions` 中添加。Token 由
EdgeOne Makers 控制台的 `API Token` 页面创建，建议使用独立描述与有限有效期，不要提交到仓库。

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

标签发布工作流会按 Linux、Windows、macOS、Web 四个平台并行构建；Web 汇总产物验证通过后，
同样部署到该项目。

## 自定义域名

1. 在 EdgeOne Makers 项目 `shouwang` 中添加自定义域名
   `2026shouwang.needhelp.icu`。
2. 读取 EdgeOne 给出的 CNAME 目标。
3. 在 `needhelp.icu` 的 DNSPod / 腾讯云 DNS 控制台添加：
   - 主机记录：`2026shouwang`
   - 记录类型：`CNAME`
   - 记录值：EdgeOne 提供的目标域名
   - TTL：600 秒或控制台允许的默认值
4. 等待 CNAME 生效后，在 EdgeOne 申请自动免费 SSL 证书。
5. 验证 HTTP 跳转、HTTPS 证书链、游戏资源与浏览器控制台。

免费证书由 EdgeOne 自动申请、部署和续期；CNAME 未指向 EdgeOne 时自动验证不会完成。
