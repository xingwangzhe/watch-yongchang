# Cloudflare Pages Web 部署

## 产物策略

GitHub Actions 先构建一次 Godot Web 产物，再分别上传到 EdgeOne Makers 与
Cloudflare Pages。两个平台使用同一份 `game/build/web/`，不重复编译引擎。

Cloudflare Pages 使用 Wrangler Direct Upload：

```bash
bunx -y wrangler@4.168.0 pages deploy game/build/web \
  --project-name shouwang \
  --branch main
```

根目录 `wrangler.jsonc` 固定项目名、兼容日期与默认产物目录，避免本地和 CI
使用不同配置。Web 产物仍为单线程、无 COOP/COEP 依赖；单个文件必须低于
Cloudflare Pages 的 25 MiB 限制。

## GitHub Actions 配置

仓库 Actions 需要：

```text
Secret:   CLOUDFLARE_API_TOKEN
Variable: CLOUDFLARE_ACCOUNT_ID
Variable: CLOUDFLARE_PAGES_PROJECT
```

Token 仅授予账号级 `Pages Read` 与 `Pages Write`，有效期至 2027-11-25。
Token 不得写入仓库、日志、Release 说明或文档。

`verify.yml` 在 `main` 推送与手工触发时并行部署：

- EdgeOne Makers 项目 `shouwang`
- Cloudflare Pages 项目 `shouwang`

`release.yml` 在标签发布时同样部署两个平台；EdgeOne 继续作为并行镜像。
自定义域名使用已配置好的 DNSPod 海内外分流：境外走 Cloudflare Pages，
境内走 EdgeOne 镜像。部署脚本不得修改 DNS/CNAME，避免覆盖既有分流。

官方参考：
<https://developers.cloudflare.com/pages/get-started/direct-upload/#wrangler-cli>

## 线上资源

- Pages 项目：`shouwang`
- Pages 子域：`shouwang-p5c.pages.dev`
- 自定义域：`https://2026shouwang.needhelp.icu`
- DNS：保留现有 DNSPod 海内外分流记录，不由本仓库部署流程修改
- 证书：Cloudflare Pages 自动签发

自定义域在 Pages 控制台中添加后会先进入 pending；只有 CNAME 生效并完成
HTTP 验证后才转为 active。分流记录的维护以 DNSPod 控制台的人工配置为准，
不要为了部署或回滚自动重写 CNAME。

## 已验证

- Pages 项目创建成功，Direct Upload 返回生产部署成功。
- 自定义域验证与证书状态为 `active`。
- `https://shouwang-p5c.pages.dev/` 返回 `200` 与当前游戏 HTML。
- 自定义域名遵循既有的海内外分流；本仓库只更新两端内容，不改 DNS。
