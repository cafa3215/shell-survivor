# 自定义域名 · 多项目门户

> 目标：`https://www.sbhigakf215dadjwahi.xyz/` 打开后**先选项目**，再进入 OUR STORY、游戏或后续新项目。

作品集门户源码在 workspace 根目录 **`portfolio/`**。

## 部署方式

| 你的托管 | 文档 |
|----------|------|
| **Vercel**（当前域名指向 Vercel） | [portfolio/README.md](../../portfolio/README.md) |
| 自有 VPS + Nginx | 本文档下方步骤 |

---

## Vercel 快速指引

1. OUR STORY 已配置 `baseURL: '/story/'`，重新部署后确认 `*.vercel.app/story` 可访问
2. 在 Vercel 新建项目，Root Directory = `portfolio`
3. 设置 `STORY_DEPLOY_URL=https://our-story-seven-zeta.vercel.app`
4. 把域名从 OUR STORY 项目移到 portfolio 项目

详见 [portfolio/README.md](../../portfolio/README.md)。

---

## VPS 部署（需服务器 IP）

## 站点结构

```text
https://www.sbhigakf215dadjwahi.xyz/
├── /                 作品集门户（选项目）
├── /story/           OUR STORY 回忆馆
├── /game/            Shell Survivor 游戏
├── /muse/            Creative Muse AI 创意引擎
└── /housing/         郑州房价预测
```

服务器目录对应关系：

```text
/var/www/portal/
├── index.html        ← portfolio/
├── portal.css
├── portal.js
├── projects.json     ← 新增/下线项目只改这里
├── story/            ← OUR STORY 整站迁到这里
├── game/             ← Godot Web 导出
├── muse/             ← Creative Muse 前端构建
└── housing/          ← 房价预测（反向代理到 FastAPI）
```

---

## 第一步：迁移 OUR STORY（从根路径到 /story/）

你现在 `www` 根路径直接是 OUR STORY 登录页，需要改成子路径。

### 若是静态站 / 前端构建产物（Vue / React / Vite 等）

1. 在 OUR STORY 项目里设置 **base 路径**：
   - Vite：`vite.config.ts` → `base: '/story/'`
   - Vue CLI：`publicPath: '/story/'`
   - Next.js：`basePath: '/story'`
2. 重新 `build`
3. 把构建结果上传到服务器 `/var/www/portal/story/`

### 若是 Node 后端（Express / Nest 等）

Nginx 用反向代理，见 `deploy/nginx-portal.conf` 底部注释，把 `/story/` 代理到本机端口。

### 迁移检查

- [ ] 打开 `https://www.sbhigakf215dadjwahi.xyz/story/` 能登录
- [ ] 静态资源路径没有 404（多为 base 未改）

---

## 第二步：导出游戏到 /game/

```powershell
$env:GODOT_EXE = "你的Godot.exe"
.\tools\export_web.ps1
```

导出结果在 `build/web/game/`（已配置子路径）。

---

## 第三步：部署门户 + 游戏

```powershell
# 推荐：从 workspace 根目录 portfolio/ 部署
cd ..\portfolio
.\deploy.ps1 -Host root@你的服务器IP -WithGame

# 或从肉鸽项目（自动读取 portfolio/ 目录）
.\tools\deploy_portal.ps1 -Host root@你的服务器IP
```

仅更新门户卡片（不改游戏）：

```powershell
.\tools\deploy_portal.ps1 -Host root@你的IP -SkipGame
```

---

## 第四步：Nginx

```bash
sudo cp deploy/nginx-portal.conf /etc/nginx/conf.d/portal.conf
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d www.sbhigakf215dadjwahi.xyz -d sbhigakf215dadjwahi.xyz
```

---

## 以后新增第三个项目

1. 编辑 `deploy/portal/projects.json`，增加一项：

```json
{
  "id": "blog",
  "title": "我的博客",
  "desc": "简短说明",
  "tag": "博客",
  "path": "/blog/",
  "enabled": true
}
```

2. 在服务器创建 `/var/www/portal/blog/` 并上传项目文件
3. 在 `nginx-portal.conf` 增加：

```nginx
location /blog/ {
    alias /var/www/portal/blog/;
    try_files $uri $uri/ /blog/index.html;
}
```

4. `sudo nginx -t && sudo systemctl reload nginx`
5. `.\tools\deploy_portal.ps1 -Host ... -SkipGame` 更新门户页

---

## 手机访问

- 打开 `https://www.sbhigakf215dadjwahi.xyz/` → 点「Shell Survivor」
- 或直接 `https://www.sbhigakf215dadjwahi.xyz/game/`
- 游戏横屏，左下摇杆 + 右下冲刺

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `deploy/portal/` | 门户首页静态文件 |
| `deploy/nginx-portal.conf` | Nginx 多项目路由 |
| `tools/deploy_portal.ps1` | 上传门户 + 游戏 |
| `tools/export_web.ps1` | 导出 Web 到 `build/web/game/` |
