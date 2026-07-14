# 手机端线上部署指南

> 目标：用手机浏览器打开网站链接就能玩（无需安装 App）。  
> 项目已按「同一套 Web 包、按设备自适应」设计：PC 键鼠 + 手机触屏共用 `build/web/game/`。

---

## 方案对比

| 方案 | 难度 | 手机体验 | 推荐 |
|------|------|----------|------|
| **Web（浏览器）** | ★☆☆ | 打开链接即玩，触摸摇杆 + 技能按钮 | ✅ 首选 |
| **作品集门户 `/game/`** | ★★☆ | 与 PC 同一域名，手机横屏进入 | ✅ 正式环境 |
| **itch.io 托管** | ★☆☆ | 上传 ZIP 即可试玩 | 快速分享 |
| **GitHub Pages** | ★★☆ | 推送后自动构建 | 有 GitHub 时用 |
| **Android APK** | ★★★ | 原生 App，需 SDK/签名 | 想要桌面图标时 |

---

## 手机端已内置的操作

| 操作 | 手机 | PC |
|------|------|-----|
| 移动 | 左下虚拟摇杆 | WASD / 方向键 |
| 冲刺 | 右上「冲刺」 | 空格 |
| 暂停 | 右上「暂停」 | Esc |
| 主动技能（激光） | 右下「激光」按住 | R / 鼠标右键 |
| 武器攻击 | 自动瞄准最近敌人 | 自动 / 半自动 |

首次用手机打开时，页面会默认 **50% 显示比例**（可在右下角切换 50/75/100%）。

---

## 第一步：本机导出 Web 包

### 1. 安装 Godot 4.6+

- 下载：[godotengine.org/download](https://godotengine.org/download)
- 打开本项目后：**编辑器 → 管理导出模板 → 下载并安装**（选 4.6）

### 2. 导出

**方式 A — 编辑器**

1. **项目 → 导出**
2. 选择预设 **「Web Mobile」**
3. 导出到 `build/web/game/index.html`

**方式 B — 命令行（推荐）**

```powershell
$env:GODOT_EXE = "E:\Desktop\Godot_v4.6.2-stable_win64.exe"
.\tools\export_web.ps1
```

导出成功后，`build/web/game/` 内会有 `index.html`、`.wasm`、`.pck` 等文件。

### 3. 本机预览（含手机同 WiFi 测试）

```powershell
npx serve build/web/game -l 3000
```

- PC：`http://localhost:3000`
- 手机：`http://你的电脑IP:3000`（需同一 WiFi）

> 首次加载约 10–60 秒（WASM + 资源包），请横屏等待进度条走完。

---

## 第二步：部署到线上

### 选项 A — 作品集门户（正式域名）

若使用 `docs/CUSTOM_DOMAIN_DEPLOY.md` 中的 VPS 门户：

```powershell
.\tools\export_web.ps1
.\tools\deploy_portal.ps1
```

手机访问：`https://你的域名/game/`

Nginx 已配置 `.wasm` / `.pck` MIME 与 gzip；大文件传输会更快。

### 选项 B — itch.io（约 5 分钟）

1. 注册 [itch.io](https://itch.io)
2. **Create new project** → 选 **HTML**
3. 把 `build/web/game/` **文件夹内所有文件**打成 ZIP 上传
4. 勾选 **This file will be played in the browser**
5. 发布后将链接发到手机打开

### 选项 C — GitHub Pages

1. 推送代码到 GitHub
2. **Settings → Pages → Source: GitHub Actions**
3. `.github/workflows/deploy-web.yml` 会自动构建
4. 访问：`https://你的用户名.github.io/仓库名/game/`

---

## 第三步（可选）：Android APK

仅当你希望「像 App 一样从桌面图标启动」时使用；**与手机浏览器玩是两条独立路径**。

1. Godot 安装 **Android 导出模板**
2. 安装 **JDK 17** + **Android SDK**（编辑器 → 编辑器设置 → 导出 → Android）
3. **项目 → 导出 → Android** → 导出 `build/android/ShellSurvivor.apk`
4. 手机开启「允许安装未知来源」后侧载安装

当前 Android 预设未签名、无启动图标，适合内测；上架商店需另行签名与素材。

---

## 体验建议

- **横屏**游玩（项目配置 `sensor_landscape`，HTML 壳提示横屏）
- 卡顿可在游戏内降低画质 / 关闭粒子
- iOS Safari：可「添加到主屏幕」全屏玩（PWA 已开启）
- 右下角 HTML「显示比例」在手机上会移到右上角，避免挡住游戏内「激光」按钮

---

## 常见问题

**Q: 导出时报「找不到模板」**  
A: 编辑器 → 管理导出模板 → 安装与编辑器同版本模板。

**Q: 手机白屏或一直加载**  
A: 确认服务器支持 `application/wasm`；弱网下多等一会或换 WiFi。

**Q: 能移动但不能放激光**  
A: 确认已重新导出并强刷（Ctrl+Shift+R / 清除缓存）；触屏应显示右下「激光」按钮，需**按住**。

**Q: 包太大**  
A: Web 预设已排除 `assets/vendor/` 等大目录；后续可做资源分包或进一步裁剪 KayKit 资源。

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `export_presets.cfg` | Web Mobile / Android 导出预设 |
| `deploy/custom_shell.html` | 手机自适应 HTML 外壳（缩放、横屏提示） |
| `scripts/autoload/InputManager.gd` | 触屏检测、`is_touch_ui()` |
| `scripts/autoload/ActiveSkillManager.gd` | 激光按住 + 触屏瞄准 |
| `scripts/ui/HUD.gd` | 摇杆、冲刺、激光按钮 |
| `tools/export_web.ps1` | 本机一键导出 |
| `tools/deploy_portal.ps1` | 部署到 VPS 门户 |
| `deploy/nginx-portal.conf` | `/game/` 路由与 gzip |
| `.github/workflows/deploy-web.yml` | GitHub Pages 自动部署 |
