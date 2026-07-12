# 自定义域名部署：sbhigakf215dadjwahi.xyz

> 你的域名 **当前已有一个网站**（OUR STORY 登录页）。  
> 建议用 **子域名** 挂游戏，避免覆盖现有站点。

---

## 推荐结构

| 地址 | 用途 |
|------|------|
| `https://www.sbhigakf215dadjwahi.xyz/` | 保留现有站点 |
| `https://game.sbhigakf215dadjwahi.xyz/` | **Shell Survivor 游戏**（推荐） |

若你确定要 **整站替换** 为游戏，见文末「方案 B」。

---

## 第一步：本机导出 Web 包

1. 安装 Godot 4.6 + **Web 导出模板**
2. 打开本项目 → **项目 → 导出 → Web Mobile**
3. 导出到 `build/web/index.html`

或：

```powershell
$env:GODOT_EXE = "D:\Godot\Godot_v4.6-stable_win64.exe"
.\tools\export_web.ps1
```

---

## 第二步：上传到服务器

### 若你已有 VPS / 云服务器（和现有 www 站同一台）

```powershell
# 示例：替换为你的 SSH 用户名和服务器 IP
.\tools\deploy_web.ps1 -Host root@123.45.67.89 -RemoteDir /var/www/shell-survivor
```

服务器上安装 Nginx 配置（子域名方案）：

```bash
sudo mkdir -p /var/www/shell-survivor
sudo cp deploy/nginx-shell-survivor.conf /etc/nginx/conf.d/shell-survivor.conf
# 编辑 server_name / root 路径后：
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d game.sbhigakf215dadjwahi.xyz   # 免费 HTTPS
```

### DNS 设置（域名控制台）

新增一条记录：

| 类型 | 主机记录 | 记录值 |
|------|----------|--------|
| A | `game` | 你的服务器公网 IP |

等待 5–30 分钟生效后，手机浏览器打开：

**https://game.sbhigakf215dadjwahi.xyz/**

---

## 方案：Cloudflare Pages + 自定义域名（无服务器时）

若域名在 **Cloudflare** 管理：

1. [Cloudflare Dashboard](https://dash.cloudflare.com) → **Workers & Pages** → Create → **Pages**
2. 连接 GitHub 仓库，或 **Direct Upload** 上传 `build/web` 文件夹
3. Build 命令留空，输出目录 `build/web`（Direct Upload 则跳过构建）
4. **Custom domains** → 添加 `game.sbhigakf215dadjwahi.xyz`
5. Cloudflare 会自动配 SSL

仓库已含 `.github/workflows/deploy-web.yml`，推送到 GitHub 后可自动构建。

---

## 方案 B：直接占用 www 根域名

⚠️ 会 **替换** 当前的 OUR STORY 登录站。

1. 将 `build/web/` 上传到现有 www 站点的 `root` 目录（备份原站文件）
2. 确保 Nginx/Apache 对 `.wasm` 返回 `application/wasm`
3. 访问 `https://www.sbhigakf215dadjwahi.xyz/`

---

## 手机端验证清单

- [ ] 横屏打开链接
- [ ] 左下摇杆可移动
- [ ] 右下冲刺按钮可用
- [ ] 选专精 / 遗物面板有文字
- [ ] 首次加载 10–30 秒内进入主菜单

---

## 常见问题

**白屏 / 一直加载**  
检查服务器是否返回正确 MIME（见 `deploy/nginx-shell-survivor.conf`）。

**Mixed Content**  
必须用 **HTTPS** 打开；HTTP 下部分浏览器会拦截 WASM。

**想改子域名名字**  
把 `game` 换成任意前缀（如 `play`），同步改 Nginx `server_name` 和 DNS。

---

## 相关文件

- `deploy/nginx-shell-survivor.conf` — Nginx 配置
- `deploy/_headers` — Cloudflare Pages 头信息
- `tools/deploy_web.ps1` — SCP/rsync 上传脚本
- `docs/MOBILE_DEPLOY.md` — 通用手机 Web 部署
